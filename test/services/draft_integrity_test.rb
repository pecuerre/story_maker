require "test_helper"

# Which remembered changes the applier could not read at all.
#
# `test/controllers/drafts_controller_test.rb` and
# `test/controllers/review_requests_controller_test.rb` cover what a caller does about
# the answer — a refusal in words, nothing written, the draft still open. What is only
# answerable here is the rule itself, and it is a narrow one on purpose: this class exists
# to stop an exception escaping a controller as a 404, so the rows it flags are the rows
# the applier would raise on. A change it would merely *report* belongs to
# `DraftConflictDetector` and is asserted there, and a case here that flagged one of those
# would be a new refusal dressed up as a clearer answer.
class DraftIntegrityTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_one)
    @character = characters(:character_one)
  end

  test "a draft whose changes are all readable is not damaged" do
    draft = draft_with(
      change(action: "create", type: "Character", payload: { "name" => "First" }),
      change(action: "update", record: @character, payload: { "name" => "Renamed" }),
      change(action: "delete", record: @character)
    )

    assert_not_predicate DraftIntegrity.new(draft), :damaged?
  end

  test "a create naming a record type outside the registry is unreadable, and says which type" do
    # `DraftChange` refuses this at validation — a registry gate is what keeps a stored
    # type from being a loadable-constant injection — so the row can only have been
    # written by something that is not this application. `update_column` skips both the
    # callbacks and the validations, which is exactly how to reproduce one.
    draft = draft_with(change(action: "create", type: "Character", payload: { "name" => "First" }))
    draft.draft_changes.sole.update_column(:record_type, "RetiredModel")

    integrity = DraftIntegrity.new(draft)

    assert_predicate integrity, :damaged?
    offender = integrity.offenders.sole
    assert_predicate offender, :unknown_record_type?
    assert_nil offender.attribute
  end

  test "a payload naming a value the model has no writer for is unreadable, and says which one" do
    draft = draft_with(change(action: "create", type: "Character", payload: { "name" => "First", "wibble" => 1 }))

    offender = DraftIntegrity.new(draft).offenders.sole

    assert_predicate offender, :unknown_attribute?
    assert_equal "wibble", offender.attribute
  end

  test "an update the record resolves, carrying a value it cannot be handed, is unreadable" do
    draft = draft_with(change(action: "update", record: @character, payload: { "name" => "Renamed", "wibble" => 1 }))

    assert_predicate DraftIntegrity.new(draft), :damaged?
  end

  test "a remembered photo and a tag list are readable, because both have a writer that is not a column" do
    # The two shapes a check against `column_names` would call damaged, and both are
    # ordinary remembered values: `HasPhoto` keeps the cropped square in an instance
    # variable, and a tag assignment arrives as an id list the model writes through a
    # collection writer. Both are in `draft_mutation_test.rb` for every controller that
    # has them, so this is the other half of that contract: they still apply.
    draft = draft_with(
      change(action: "create", type: "Character",
        payload: { "name" => "With a face", "photo_data" => "data:image/png;base64,AAA" }),
      change(action: "update", record: @character, payload: { "character_tag_ids" => [ character_tags(:character_tag_one).id ] })
    )

    assert_not_predicate DraftIntegrity.new(draft), :damaged?
  end

  test "an update or a delete whose record type is outside the registry belongs to the detector, not here" do
    # The applier resolves the record through `DraftConflictDetector` and reports
    # `:missing` without raising, so neither is unreadable: flagging them would turn a
    # skipped change into a run that cannot happen at all.
    draft = draft_with(change(action: "update", record: @character, payload: { "name" => "Renamed" }))
    draft.draft_changes.sole.update_column(:record_type, "RetiredModel")

    assert_not_predicate DraftIntegrity.new(draft), :damaged?
  end

  test "the offenders are the changes themselves, in the order they were remembered" do
    draft = draft_with(
      change(action: "create", type: "Character", payload: { "name" => "First" }),
      change(action: "create", type: "Character", payload: { "name" => "Second", "wibble" => 1 })
    )
    draft.draft_changes.first.update_column(:record_type, "RetiredModel")

    offenders = DraftIntegrity.new(draft).offenders

    assert_equal 2, offenders.size
    assert_equal [ "First", "Second" ], offenders.map { |offender| offender.change.payload["name"] }
    assert_equal [ :unknown_record_type, :unknown_attribute ], offenders.map(&:reason)
    assert_equal "wibble", offenders.last.attribute
    assert_equal DraftIntegrity::REASONS.sort, offenders.map(&:reason).sort
  end

  private
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
