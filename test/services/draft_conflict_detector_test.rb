require "test_helper"

# Whether a remembered change can still be written, and what the record it names
# looks like now.
#
# `test/services/draft_applier_test.rb` holds what an apply *does* with each of
# these answers. What is only answerable here is the rule itself: every row of it,
# including the two that are not conflicts — an already-deleted delete and a
# record that does not resolve — because those are the rows that would be lost if
# they were only ever reached through an apply that also had a transaction to run.
class DraftConflictDetectorTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_one)
    @character = characters(:character_one)
  end

  test "a create names no record, so it cannot conflict" do
    draft = draft_with(change(action: "create", type: "Character", payload: { "name" => "First" }))

    report = detector(draft).report_for(draft.draft_changes.sole)

    assert_predicate report, :writable?
    assert_not_predicate report, :conflict?
    assert_nil report.record
  end

  test "an update the record has not moved since can be written" do
    draft = draft_with(change(action: "update", record: @character, payload: { "name" => "Renamed" }))

    report = detector(draft).report_for(draft.draft_changes.sole)

    assert_predicate report, :writable?
    assert_equal @character, report.record
  end

  test "an update the record has moved since is a conflict, and the report carries the current state" do
    draft = draft_with(change(action: "update", record: @character, payload: { "name" => "Renamed" }))
    @character.update!(name: "Somebody else was here")

    report = detector(draft).report_for(draft.draft_changes.sole)

    assert_predicate report, :conflict?
    assert_equal :moved, report.state
    assert_equal :moved, report.conflict_reason
    # The record is what "theirs" would mean, so the report hands back the row as it
    # is now rather than the version the change was remembered against.
    assert_equal "Somebody else was here", report.record.name
  end

  test "an update whose record somebody has deleted is a conflict, reported as deleted rather than moved" do
    draft = draft_with(change(action: "update", record: @character, payload: { "name" => "Renamed" }))
    @character.soft_delete

    report = detector(draft).report_for(draft.draft_changes.sole)

    assert_predicate report, :conflict?
    # `soft_delete` moves `updated_at` as well as writing `deleted_at`, so asking the
    # version first would report this as `:moved` and make `:deleted` unreachable.
    # The useful answer is the one that says the record is gone.
    assert_equal :deleted, report.state
    assert_predicate report.record, :deleted?
    assert_not_nil Character.with_deleted.find_by(id: @character.id), "the row is still there to restore"
  end

  test "a delete the record has not moved since can be written" do
    location = locations(:location_one)
    draft = draft_with(change(action: "delete", record: location))

    report = detector(draft).report_for(draft.draft_changes.sole)

    assert_predicate report, :writable?
    assert_equal location, report.record
  end

  test "a delete the record has moved since is a conflict" do
    location = locations(:location_one)
    draft = draft_with(change(action: "delete", record: location))
    location.update!(name: "Somebody else renamed this")

    assert_equal :moved, detector(draft).report_for(draft.draft_changes.sole).state
  end

  test "a delete whose record is already deleted is not a conflict: the intent already holds" do
    location = locations(:location_one)
    draft = draft_with(change(action: "delete", record: location))
    location.soft_delete

    report = detector(draft).report_for(draft.draft_changes.sole)

    assert_not_predicate report, :conflict?
    assert_not_predicate report, :writable?
    assert_equal :gone, report.state
    assert_nil report.conflict_reason
  end

  # `DraftChange` refuses to *store* either of these two shapes — a named record
  # has to resolve and has to belong to the draft's universe — so they are reached
  # the way a corrupt or legacy row is: written against a real record, then
  # rewritten behind the model's back. They are still answers the detector has to
  # give, because a row that cannot be trusted to have been valid is exactly the
  # row an apply must not act on.
  test "a change whose record does not resolve is missing rather than in conflict" do
    draft = draft_with(
      change(action: "update", record: @character, payload: { "name" => "Renamed" }),
      change(action: "delete", record: locations(:location_one))
    )
    draft.draft_changes.each_with_index do |stored, index|
      stored.update_column(:record_id, @character.id + 100_000 + index)
    end

    reports = detector(draft).reports

    assert_equal %i[missing missing], reports.map(&:state)
    assert_empty detector(draft).conflicts, "a conflict an author cannot act on is not reported as one"
  end

  test "a change naming a record in another universe is missing, not written into this one" do
    elsewhere = universes(:universe_two).characters.create!(name: "Somebody else's character")
    draft = draft_with(change(action: "update", record: @character, payload: { "name" => "Mine now" }))
    draft.draft_changes.sole.update_column(:record_id, elsewhere.id)

    report = detector(draft).report_for(draft.draft_changes.reload.sole)

    assert_equal :missing, report.state
    assert_not_equal "Mine now", elsewhere.reload.name
  end

  test "a change naming a type outside the content registry is reported rather than raised" do
    draft = draft_with(change(action: "update", record: @character, payload: { "name" => "Renamed" }))
    draft.draft_changes.sole.update_column(:record_type, "Session")

    # The applier raises on a **create** it cannot build a class for, because that
    # has no answer to report; a change that names a record does, and this is it.
    report = detector(draft).report_for(draft.draft_changes.reload.sole)

    assert_equal :missing, report.state
    assert_not_predicate report, :conflict?
  end

  test "a change with no remembered version counts as moved rather than written" do
    draft = draft_with(change(action: "update", record: @character, payload: { "name" => "Renamed" }))
    draft.draft_changes.sole.update_column(:base_version, nil)

    # `VersionStamp`'s conservative direction: a base this change cannot be compared
    # against is reported rather than quietly overwritten.
    assert_equal :moved, detector(draft).report_for(draft.draft_changes.reload.sole).state
  end

  test "conflicts lists the conflicting changes in the order they were remembered" do
    draft = draft_with(
      change(action: "create", type: "Character", payload: { "name" => "First" }),
      change(action: "update", record: @character, payload: { "name" => "Renamed" }),
      change(action: "delete", record: locations(:location_one))
    )
    @character.update!(name: "Somebody else was here")

    conflicts = detector(draft).conflicts

    assert_equal 1, conflicts.size
    assert_equal %w[update], conflicts.map { |conflict| conflict.change.action }
    assert_equal conflicts.sole, detector(draft).conflict_for(draft.draft_changes.second),
      "asking about one change gives the same answer the list gives it"
  end

  test "conflict_for is nil for a change that is not in conflict" do
    draft = draft_with(change(action: "delete", record: locations(:location_one)))

    assert_nil detector(draft).conflict_for(draft.draft_changes.sole)
  end

  test "the conflict states are the two the detector and the applier agree on" do
    assert_equal %i[moved deleted], DraftConflictDetector::CONFLICT_REASONS
    assert_equal DraftConflictDetector::CONFLICT_REASONS.sort, DraftApplier::SKIP_REASONS.first(2).sort,
      "a conflict is reported under one vocabulary, not two that can drift"
    assert_equal DraftConflictDetector::CONFLICT_REASONS.sort,
      DraftConflictDetector::CONFLICT_REASONS.sort & DraftApplier::SKIP_REASONS
  end

  test "a model's own columns decide whether a reference can be soft-deleted at all" do
    # `find_including_deleted` asks the model as a capability, and a `Photo` — which
    # is destroyed rather than marked — has to answer as though nothing could be
    # deleted. A model that grows a `deleted_at` column without the concern is the
    # case that would otherwise answer wrongly and silently.
    soft_deletable = Ability::CONTENT_CLASS_NAMES.select { |name| name.constantize.column_names.include?("deleted_at") }
    not_soft_deletable = Ability::CONTENT_CLASS_NAMES - soft_deletable

    assert_predicate soft_deletable, :any?
    soft_deletable.each { |name| assert_respond_to name.constantize, :with_deleted, name }
    not_soft_deletable.each do |name|
      model = name.constantize
      assert_not_respond_to model, :with_deleted, name
      assert_not_includes model.column_names, "deleted_at", name
    end
  end

  private
    def detector(draft)
      DraftConflictDetector.new(draft)
    end

    def draft_with(*changes)
      Draft.create!(user: @user, universe: @universe).tap do |draft|
        changes.each { |attributes| draft.draft_changes.create!(attributes) }
      end
    end

    def change(action:, type: nil, record: nil, payload: nil)
      creating = action == "create"

      { action: action, record_type: type || record.class.name, record_id: creating ? nil : record.id,
        base_version: creating ? nil : DraftChange.capture_base_version(record), payload: payload }
    end
end
