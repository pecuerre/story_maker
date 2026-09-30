require "test_helper"

# The serialized hand-off the modal editors are prefilled from. Two contracts are
# pinned here, because both were silent: a stored second was dropped on the way
# out (so opening an editor and saving rewrote the column to zero seconds), and
# Relation/Ownership shipped no `name` key at all while their models prefer one
# for `display_string` and the composite slug.
class ModalFieldsHelperTest < ActionView::TestCase
  include ApplicationHelper
  include ModalFields

  setup do
    @universe = universes(:universe_one)
  end

  test "an Event's datetimes keep the seconds they were stored with" do
    event = Event.create!(universe: @universe, title: "Precise",
      start_datetime: Time.utc(2026, 9, 11, 9, 0, 30), end_datetime: Time.utc(2026, 9, 11, 10, 15, 45))

    assert_equal "2026-09-11T09:00:30", serialized(event)["start_datetime"]
    assert_equal "2026-09-11T10:15:45", serialized(event)["end_datetime"]
  end

  test "a Relation's interval keeps its seconds and carries the optional name" do
    relation = Relation.create!(universe: @universe, character1: characters(:character_one),
      character2: characters(:character_two), name: "Family", from_date: Time.utc(2026, 1, 2, 3, 4, 5),
      to_date: Time.utc(2027, 1, 2, 3, 4, 6))

    assert_equal "Family", serialized(relation)["name"]
    assert_equal "2026-01-02T03:04:05", serialized(relation)["from_date"]
    assert_equal "2027-01-02T03:04:06", serialized(relation)["to_date"]
  end

  test "an Ownership's interval keeps its seconds and carries the optional name" do
    ownership = Ownership.create!(universe: @universe, item: items(:item_one),
      character: characters(:character_one), name: "Heirloom", from_date: Time.utc(2026, 1, 2, 3, 4, 5),
      to_date: Time.utc(2027, 1, 2, 3, 4, 6))

    assert_equal "Heirloom", serialized(ownership)["name"]
    assert_equal "2026-01-02T03:04:05", serialized(ownership)["from_date"]
    assert_equal "2027-01-02T03:04:06", serialized(ownership)["to_date"]
  end

  test "an unset datetime and name serialize as nil, so the editor opens empty" do
    relation = Relation.create!(universe: @universe, character1: characters(:character_one),
      character2: characters(:character_two))

    assert_nil serialized(relation)["name"]
    assert_nil serialized(relation)["from_date"]
    assert_nil serialized(relation)["to_date"]
    assert_nil serialized(Relation.new)["name"]
  end

  test "the shared format keeps the second the display format leaves out" do
    # Two formats, two jobs: `DATE_FORMAT` is what a reader is shown, and
    # `DATETIME_LOCAL_FORMAT` is what a `datetime-local` control is handed. Only
    # the second one has to keep seconds, because a control whose step is a whole
    # minute cannot hold one and would drop it on save.
    stored = Time.utc(2026, 9, 11, 9, 30, 45)

    assert_equal "2026-09-11 09:30", stored.strftime(ApplicationHelper::DATE_FORMAT)
    assert_equal "2026-09-11T09:30:45", stored.strftime(ApplicationHelper::DATETIME_LOCAL_FORMAT)
  end

  private
    def serialized(record)
      case record
      when Event then JSON.parse(event_fields_json(record))
      when Relation then JSON.parse(relation_fields_json(record))
      when Ownership then JSON.parse(ownership_fields_json(record))
      end
    end
end
