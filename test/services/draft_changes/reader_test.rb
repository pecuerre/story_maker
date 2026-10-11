require "test_helper"

# One draft's changes, read in a fixed number of queries.
#
# This is the read side of finding 66. Before this class, a page that drew a draft asked
# the database once per row — `DraftChange#resolved_record` for the record a change names,
# `DraftsHelper#association_names` for every tag id in its payload, and a discarded
# `includes` for its outcome — so the sidebar's pending panel cost that on every page of
# the universe. The reader asks once per **class** instead of once per id.
#
# **The assertions here are about two things: the number of queries, and the answers being
# the same ones the per-row reads gave.** A batched read that quietly returned a different
# set would be worse than the N+1 it replaced, so every refusal the old path had is
# pinned here: an unregistered type, a record somebody has since deleted, a tag id that no
# longer resolves, a soft-deleted tag, and a create's absent record.
class DraftChanges::ReaderTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @character = characters(:character_one)
    @draft = Draft.create!(user: users(:user_one), universe: @universe)
  end

  # Records

  test "every record the changes name is resolved, and one query per class covers them all" do
    location = locations(:location_one)
    item = items(:item_one)
    @draft.draft_changes.create!(action: "update", record_type: "Character", record_id: @character.id,
      base_version: DraftChange.capture_base_version(@character), payload: { "name" => "One" })
    @draft.draft_changes.create!(action: "delete", record_type: "Location", record_id: location.id,
      base_version: DraftChange.capture_base_version(location))
    @draft.draft_changes.create!(action: "delete", record_type: "Item", record_id: item.id,
      base_version: DraftChange.capture_base_version(item))

    reader = reader_for(@draft)

    assert_equal @character, reader.entry_for(change_named(@character)).record
    assert_equal location, reader.entry_for(change_named(location)).record
    assert_equal item, reader.entry_for(change_named(item)).record
    # Three classes, so three queries however many changes name them. A **fresh** reader
    # inside the block: `entries` memoizes, and a reader that had already answered would
    # report zero and make the assertion mean nothing.
    assert_equal 3, count_records_queries { reader_for(@draft).entries }
  end

  test "many changes about one record still cost one query" do
    5.times do |index|
      @draft.draft_changes.create!(action: "update", record_type: "Character", record_id: @character.id,
        base_version: DraftChange.capture_base_version(@character), payload: { "name" => "Name #{index}" })
    end

    reader = reader_for(@draft)

    assert_equal 1, count_records_queries { reader_for(@draft).entries }
    assert_equal [ @character ], reader.entries.map(&:record).uniq
  end

  test "a remembered create resolves no record and costs no query" do
    @draft.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "universe_id" => @universe.id, "name" => "Ariadne" })

    reader = reader_for(@draft)

    # The per-row read this replaced asked `RecordTarget` with a nil id, which issued
    # `WHERE id IS NULL` and could not answer.
    assert_nil reader.entries.first.record
    assert_equal 0, count_records_queries { reader_for(@draft).entries }
  end

  test "a record somebody has since deleted resolves to nothing, as it did per row" do
    change = @draft.draft_changes.create!(action: "update", record_type: "Character", record_id: @character.id,
      base_version: DraftChange.capture_base_version(@character), payload: { "name" => "One" })
    @character.destroy!

    reader = reader_for(@draft)

    # `DraftChange#resolved_record` reads through `RecordTarget`, whose default scope
    # hides a soft-deleted row, and the reader's `where` inherits that scope exactly.
    assert_nil reader.entry_for(change).record
    assert_empty reader.entry_for(change).tag_records
  end

  test "a record type outside the content registry resolves to nothing and is never loaded" do
    # Built unsaved, because a `record_type` outside the registry cannot be persisted:
    # `DraftChange`'s own `record_type_names_content` validation refuses it. The reader
    # still has to answer one, because a hand-edited or older row is exactly the case
    # `DraftIntegrity` exists to catch at apply time, and this is the read side of the
    # same gate.
    stranger = DraftChange.new(action: "update", record_type: "User", record_id: users(:user_one).id,
      payload: { "name" => "Renamed" })

    reader = DraftChanges::Reader.new([ stranger ])

    assert_nil reader.entry_for(stranger).record
    assert_equal 0, count_queries { DraftChanges::Reader.new([ stranger ]).entries }
  end

  # Tag ids

  test "every tag id in every payload is resolved in one query for the class" do
    first = character_tag("Protagonist")
    second = character_tag("Antagonist")
    @draft.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "universe_id" => @universe.id, "name" => "Ariadne", "character_tag_ids" => [ first.id ] })
    @draft.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "universe_id" => @universe.id, "name" => "Lysander", "character_tag_ids" => [ second.id, first.id ] })

    reader = reader_for(@draft)
    entries = reader.entries

    # **The author's order is kept, not the query's.** The second change submitted
    # "Antagonist, Protagonist" and the page has to print it that way, which is a fact
    # about what they asked for rather than about the order the rows came back in.
    assert_equal [ second, first ], entries.last.tags_for("character_tag_ids")
    assert_equal [ first ], entries.first.tags_for("character_tag_ids")
    assert_equal 1, count_tag_queries { reader_for(@draft).entries }
  end

  test "a tag id that no longer resolves is dropped rather than printed" do
    tag = character_tag("Protagonist")
    change = @draft.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "universe_id" => @universe.id, "name" => "Ariadne", "character_tag_ids" => [ tag.id, 0 ] })

    reader = reader_for(@draft)

    # The change was the author's statement about the ids that are still there, so the
    # missing one is absent rather than nil-valued.
    assert_equal [ tag ], reader.entry_for(change).tags_for("character_tag_ids")
  end

  test "a soft-deleted tag stays invisible, as it did per row" do
    tag = character_tag("Protagonist")
    change = @draft.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "universe_id" => @universe.id, "name" => "Ariadne", "character_tag_ids" => [ tag.id ] })
    tag.destroy!

    reader = reader_for(@draft)

    assert_empty reader.entry_for(change).tags_for("character_tag_ids")
  end

  test "a payload key that is not an id list resolves no tags and is asked about no class" do
    change = @draft.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "universe_id" => @universe.id, "name" => "Ariadne", "photo_data" => "data:image/png;base64,AAA" })

    reader = reader_for(@draft)

    assert_nil reader.entry_for(change).tags_for("photo_data")
    assert_equal 0, count_tag_queries { reader_for(@draft).entries }
  end

  test "a change with no payload resolves no tags" do
    change = @draft.draft_changes.create!(action: "delete", record_type: "Character", record_id: @character.id,
      base_version: DraftChange.capture_base_version(@character))

    reader = reader_for(@draft)

    assert_equal({}, reader.entry_for(change).tag_records)
    assert_equal 0, count_tag_queries { reader_for(@draft).entries }
  end

  # The scope a change would be written under

  test "a story-scoped change resolves the story it names, and one query covers them all" do
    # The scope column used to be dropped from the page as an unnameable number. It is
    # now resolved, so the reader answers it — once per **owner class**, the same bound
    # as the records and the tags, rather than once per change.
    change = @draft.draft_changes.create!(action: "create", record_type: "Scene",
      payload: { "story_id" => stories(:story_one).id, "name" => "Arrival" })

    reader = reader_for(@draft)

    assert_equal stories(:story_one), reader.entry_for(change).scope
    # A **fresh** reader inside the block: `entries` memoizes, so a reader that had
    # already answered would report zero and make the assertion mean nothing.
    assert_equal 1, count_scope_queries { reader_for(@draft).entries }
  end

  test "a universe-scoped change resolves no scope and is asked about no owner class" do
    # A Character's scope column is `universe_id`, and the page is already inside the
    # universe that names. Resolving it would load the universe on every draft page to
    # print the one thing the reader can see from the address bar.
    change = @draft.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "universe_id" => @universe.id, "name" => "Ariadne" })

    reader = reader_for(@draft)

    assert_nil reader.entry_for(change).scope
    assert_equal 0, count_scope_queries { reader_for(@draft).entries }
  end

  test "two changes of one type under different stories each resolve their own" do
    # The case a per-`record_type` key silently gets wrong, and the ordinary shape of
    # a real draft: two Scenes remembered under two stories. Keyed by type, the
    # second one's answer would be read for both and the drafts page would name one
    # story for every change on it — which is the exact confusion the scope row
    # exists to remove, reintroduced one level up.
    one = @draft.draft_changes.create!(action: "create", record_type: "Scene",
      payload: { "story_id" => stories(:story_one).id, "name" => "Arrival" })
    two = @draft.draft_changes.create!(action: "create", record_type: "Scene",
      payload: { "story_id" => stories(:story_alt).id, "name" => "Departure" })

    reader = reader_for(@draft)

    assert_equal stories(:story_one), reader.entry_for(one).scope
    assert_equal stories(:story_alt), reader.entry_for(two).scope
  end

  test "a scene-scoped change resolves the scene it names, not a scene of its own type" do
    # The key is the **owner's** class rather than `record_type`: a `SceneElement`'s
    # `scene_id` names a `Scene`, so an answer keyed by the changed type would look a
    # scene up among the scene elements and find nothing.
    scene = scenes(:scene_one)
    change = @draft.draft_changes.create!(action: "create", record_type: "SceneElement",
      payload: { "scene_id" => scene.id, "kind" => "narration", "content" => "They came" })

    assert_equal scene, reader_for(@draft).entry_for(change).scope
  end

  test "a scope record that has since been deleted resolves to nothing" do
    # A change whose story is gone is still the author's statement; what it cannot do
    # is name a story, so the answer is nil and the page says so in its own words.
    change = @draft.draft_changes.create!(action: "create", record_type: "Scene",
      payload: { "story_id" => stories(:story_one).id, "name" => "Arrival" })
    stories(:story_one).destroy!

    assert_nil reader_for(@draft).entry_for(change).scope
  end

  test "a payload naming no scope id resolves to nothing rather than raising" do
    change = @draft.draft_changes.create!(action: "create", record_type: "Scene",
      payload: { "name" => "Arrival" })

    assert_nil reader_for(@draft).entry_for(change).scope
  end

  test "a change the reader was not built with resolves no scope" do
    reader = reader_for(@draft)
    stranger = DraftChange.new(action: "create", record_type: "Scene",
      payload: { "story_id" => stories(:story_one).id })

    assert_nil reader.entry_for(stranger).scope
  end

  # Shape

  test "a change the reader was not built with resolves to nothing rather than raising" do
    reader = reader_for(@draft)
    stranger = DraftChange.new(action: "update", record_type: "Character", record_id: @character.id)

    assert_nil reader.entry_for(stranger).record
    assert_equal({}, reader.entry_for(stranger).tag_records)
  end

  test "an empty draft resolves nothing and asks nothing" do
    reader = DraftChanges::Reader.new([])

    assert_empty reader.entries
    assert_equal 0, count_queries { reader.entries }
  end

  test "entries come back in the order the changes were given" do
    location = locations(:location_one)
    order = [
      @draft.draft_changes.create!(action: "delete", record_type: "Character", record_id: @character.id,
        base_version: DraftChange.capture_base_version(@character)),
      @draft.draft_changes.create!(action: "delete", record_type: "Location", record_id: location.id,
        base_version: DraftChange.capture_base_version(location)),
      @draft.draft_changes.create!(action: "delete", record_type: "Item", record_id: items(:item_one).id,
        base_version: DraftChange.capture_base_version(items(:item_one)))
    ]

    # Reversed, because the reader reports the order it was handed rather than sorting —
    # the page draws them in the order they were remembered and the reader has no opinion
    # about that.
    reader = DraftChanges::Reader.new(order.reverse)

    assert_equal order.reverse, reader.entries.map(&:change)
  end

  private
    def reader_for(draft)
      DraftChanges::Reader.new(draft.draft_changes.to_a)
    end

    def change_named(record)
      @draft.draft_changes.find_by!(record_type: record.class.name, record_id: record.id)
    end

    def character_tag(name)
      @universe.character_tags.create!(name: name, position: @universe.character_tags.count + 1)
    end

    # Only the class's own `WHERE id IN` counts. The pattern is deliberate rather than
    # counting everything: what is being held is "how many times did the reader ask the
    # database", and a change's own validation reads are not the reader's doing.
    def count_records_queries(&block)
      count_queries(/FROM "(characters|locations|items|events|scenes|sections|stories)"/, &block)
    end

    def count_tag_queries(&block)
      count_queries(/FROM "character_tags"/, &block)
    end

    # Only the owner classes a scope column can name, and never `universes`: the point
    # of the universe-scoped test is that the reader never asks.
    def count_scope_queries(&block)
      count_queries(/FROM "(stories|scenes|sections)"/, &block)
    end
end
