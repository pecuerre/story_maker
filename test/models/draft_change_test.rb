require "test_helper"

class DraftChangeTest < ActiveSupport::TestCase
  setup do
    @draft = Draft.create!(user: users(:user_one), universe: universes(:universe_one))
    @character = characters(:character_one)
  end

  test "a change remembers an update to a record in the draft's universe" do
    change = @draft.draft_changes.create!(
      record_type: "Character", record_id: @character.id, action: "update",
      payload: { "name" => "Marth" }, base_version: DraftChange.capture_base_version(@character)
    )

    assert_equal @character, change.record
    assert_equal "Character", change.record_type
    assert_predicate change, :updating?
    assert_not change.creating?
  end

  test "a create names no record, because the record does not exist yet" do
    change = @draft.draft_changes.create!(
      record_type: "Character", action: "create", payload: { "name" => "Lysander" }
    )

    assert_predicate change, :creating?
    assert_nil change.record_id
    assert_nil change.record
    assert_nil change.base_version
  end

  test "requires a draft, an action, and a record type" do
    change = DraftChange.new(action: "update", record_type: "Character", record_id: @character.id)

    assert_not change.valid?
    assert_includes change.errors[:draft], "must exist"
  end

  test "refuses an action nothing in the application performs" do
    change = @draft.draft_changes.new(record_type: "Character", action: "merge", record_id: @character.id)

    assert_not change.valid?
    assert_includes change.errors[:action], "is not included in the list"
  end

  test "refuses a type that is not a registered content class" do
    # The registry is the gate, and it is checked as a string against
    # `CONTENT_CLASS_NAMES` before anything is constantized, so a stored type can
    # never become a loadable constant. That has to be a field error rather than a
    # `NameError`, and the same refusal for a plausible non-content class as for a
    # nonsense one.
    [ "Kernel", "ActiveRecord::Base", "NotAModel", "draft" ].each do |type|
      change = @draft.draft_changes.new(record_type: type, action: "update", record_id: @character.id)

      assert_not change.valid?, type
      assert_includes change.errors[:record_type], "must name a record this universe can hold", type
    end
  end

  test "refuses a create that names a record" do
    # The id on such a row would belong to something else, and the applier would
    # have to guess which record the payload describes.
    change = @draft.draft_changes.new(
      record_type: "Character", record_id: @character.id, action: "create", payload: { "name" => "X" }
    )

    assert_not change.valid?
    assert_includes change.errors[:record_id], "cannot name a record that does not exist yet"
  end

  test "refuses an update or a delete that names no record" do
    %w[update delete].each do |action|
      change = @draft.draft_changes.new(record_type: "Character", action: action, base_version: "x")

      assert_not change.valid?, action
      assert_includes change.errors[:record_id], "must name a record that already exists", action
    end
  end

  test "refuses an id that names nothing" do
    change = @draft.draft_changes.new(record_type: "Character", record_id: 0, action: "update", base_version: "x")

    assert_not change.valid?
    assert_includes change.errors[:record], "does not exist"
  end

  test "refuses a soft-deleted record" do
    character = universes(:universe_two).characters.create!(name: "Gone")
    change = @draft.draft_changes.new(
      record_type: "Character", record_id: character.id, action: "update", base_version: "x"
    )
    character.soft_delete

    assert_not change.valid?
    # A change to a record that cannot be found could be neither applied nor
    # conflict-checked, so it is refused with the same sentence a discussion uses.
    assert_includes change.errors[:record], "does not exist"
  end

  test "refuses a record from another universe" do
    other = universes(:universe_two).characters.create!(name: "Foreign")
    change = @draft.draft_changes.new(
      record_type: "Character", record_id: other.id, action: "update", base_version: "x"
    )

    assert_not change.valid?
    # A different sentence from "does not exist": the record is there, and saying
    # otherwise would send the reader looking for a record that is not missing.
    assert_includes change.errors[:record], "must belong to the same universe"
    assert_no_difference("DraftChange.count") { change.save }
  end

  test "refuses a record that reaches another universe through its story" do
    # A Section has no `universe_id` of its own, so this is the case where the
    # draft's universe and the record's disagree while both look valid alone.
    section = stories(:story_two).sections.create!(name: "Foreign section", slug: "foreign-section")
    change = @draft.draft_changes.new(
      record_type: "Section", record_id: section.id, action: "update", base_version: "x"
    )

    assert_not change.valid?
    assert_includes change.errors[:record], "must belong to the same universe"
    assert_equal universes(:universe_two), UniverseScopeResolver.universe_for(section)
  end

  test "refuses an existing record whose version was not remembered" do
    # Without a base version there is nothing to compare the record against, and
    # the conservative answer — an unknown base counts as moved — would report a
    # conflict on every single change. The missing stamp is caught here instead.
    change = @draft.draft_changes.new(record_type: "Character", record_id: @character.id, action: "update")

    assert_not change.valid?
    assert_includes change.errors[:base_version], "must remember the record's version"
  end

  test "refuses a version on a create, which has no record to version" do
    change = @draft.draft_changes.new(
      record_type: "Character", action: "create", payload: { "name" => "X" },
      base_version: DraftChange.capture_base_version(@character)
    )

    assert_not change.valid?
    assert_includes change.errors[:base_version], "cannot remember a version of a record that does not exist yet"
  end

  test "captures the base version as a normalized string, never as a Time" do
    # The comparison that matters happens days later, between this stored string
    # and another one. A `Time` is never equal to the string it was serialized
    # from, so a stamp written any other way would report a conflict on every
    # change — which is why this is a class method rather than something each
    # caller does for itself.
    stamp = DraftChange.capture_base_version(@character)

    assert_kind_of String, stamp
    assert_equal @character.updated_at.utc.iso8601(VERSION_STAMP_PRECISION), stamp
    assert_not VersionStamp.changed?(@character, stamp)
  end

  test "a change that has been written keeps the moment it was written" do
    change = @draft.draft_changes.create!(record_type: "Character", action: "create", payload: { "name" => "X" })

    # A change says what was observed at one moment, so the table carries
    # `created_at` and no `updated_at`: an editable timestamp would let a
    # remembered change drift from what was actually seen.
    assert_not change.has_attribute?(:updated_at)
    assert_kind_of ActiveSupport::TimeWithZone, change.created_at

    # Immutability is enforced, not just documented: a rewritten payload would
    # still carry a `base_version` captured against different attributes, and
    # nothing after the fact could tell.
    change.payload = { "name" => "Y" }

    error = assert_raises ActiveRecord::ReadOnlyRecord do
      change.save!
    end
    assert_match(/append-only/, error.message)
    assert_equal({ "name" => "X" }, change.reload.payload)
  end
end
