require "test_helper"

# What one reader's open draft would do to the page in front of them.
#
# The remembering path is covered by `test/controllers/draft_mutation_test.rb` and
# the writing by `test/services/draft_applier_test.rb`; what is left is the read
# side, and it has three answers to be right about. **A remembered create names no
# record**, so the records a list would show it come from here and nowhere else. **A
# remembered edit and a remembered delete name a record that is still stored**, so
# their badges are a lookup rather than a stored fact. And **everything is the
# reader's own**, because a draft belongs to a person and somebody else's pending
# work is not an oracle a list page may answer.
class DraftPreviewTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @universe.update!(collaboration_mode: "wikipedia")
    @author = users(:user_one)
    @draft = Draft.open_for!(@author, @universe)
  end

  # What exists to read

  test "a universe that writes changes straight through has nothing pending" do
    @universe.update!(collaboration_mode: "direct")
    preview = preview_for(@author)

    assert_not preview.available?
    assert_nil preview.draft
    assert_empty preview.changes
    assert_equal 0, preview.count
  end

  test "a guest has nothing pending" do
    preview = preview_for(nil)

    assert_not preview.available?
    assert_empty preview.changes
  end

  test "another author's pending work is not this reader's" do
    draft = Draft.open_for!(users(:user_two), @universe)
    draft.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Theirs", "universe_id" => @universe.id })

    assert_empty preview_for(@author).changes
    assert_equal 1, preview_for(users(:user_two)).count
  end

  test "a closed draft's changes are no longer pending" do
    remember_create("Character", "name" => "Ariadne")
    preview = preview_for(@author)
    assert_equal 1, preview.count

    # An applied or discarded draft is history. Its remembered intentions stop
    # counting the moment they stop being pending, which is what the open scope in
    # `Draft.pending_changes_count` already says and what a list page would
    # contradict if it read closed drafts too.
    @draft.update!(status: "applied")

    assert_equal 0, preview_for(@author).count
  end

  # What is waiting on a stored record

  test "a remembered edit reports an edit on that record and nothing on another" do
    character = characters(:character_one)
    remember_update(character, "name" => "Ariadne")

    assert_equal :edit, preview_for(@author).state_for(character)
    assert_nil preview_for(@author).state_for(characters(:character_two))
  end

  test "a remembered delete reports a deletion on that record" do
    character = characters(:character_one)
    remember_delete(character)

    assert_equal :deletion, preview_for(@author).state_for(character)
  end

  test "a deletion wins an edit on the same record" do
    # A row badged "pending edit" above a row badged "pending deletion" would give
    # one record two answers on one page, and the deletion is the one that decides
    # whether the edit matters.
    character = characters(:character_one)
    remember_update(character, "name" => "Ariadne")
    remember_delete(character)

    assert_equal :deletion, preview_for(@author).state_for(character)
  end

  test "the order the two changes were remembered in does not change which state wins" do
    character = characters(:character_one)
    remember_delete(character)
    remember_update(character, "name" => "Ariadne")

    assert_equal :deletion, preview_for(@author).state_for(character)
  end

  test "a change is keyed by the record it names, not by its type" do
    # Once a record is soft-deleted no list renders it and nothing asks about it,
    # so the change is simply left dangling. What must not happen is the change
    # attaching itself to a *different* record of the same type — which is why the
    # index is keyed by id rather than scanned by class.
    character = characters(:character_one)
    remember_update(character, "name" => "Ariadne")
    character.soft_delete

    assert_equal :edit, preview_for(@author).state_for(character)
    assert_nil preview_for(@author).state_for(characters(:character_two))
    assert_equal 1, preview_for(@author).count,
      "the change is still on the draft and is still readable on the draft's own page"
  end

  test "an unsaved record has no remembered state of its own" do
    # `DraftsHelper` answers `:draft` for one, because the only unsaved record a
    # list can hold is a synthesized pending row. The preview itself must not
    # pretend: it only knows about records a change names.
    assert_nil preview_for(@author).state_for(Character.new)
    assert_nil preview_for(@author).state_for(nil)
  end

  # What the draft would have created

  test "a remembered create is the record a list would have shown" do
    remember_create("Character", "name" => "Ariadne", "description" => "The thread puller")

    pending = preview_for(@author).creates_for(Character)

    assert_equal 1, pending.size
    record = pending.first
    assert_predicate record, :new_record?
    assert_equal "Ariadne", record.name
    assert_equal "The thread puller", record.description
  end

  test "a remembered create arrives in the order it was remembered" do
    remember_create("Character", "name" => "First")
    remember_create("Character", "name" => "Second")

    assert_equal [ "First", "Second" ], preview_for(@author).creates_for(Character).map(&:name)
  end

  test "a remembered create is asked for its own model only" do
    remember_create("Character", "name" => "Ariadne")
    remember_create("Location", "name" => "The Labyrinth")

    assert_equal [ "Ariadne" ], preview_for(@author).creates_for(Character).map(&:name)
    assert_equal [ "The Labyrinth" ], preview_for(@author).creates_for(Location).map(&:name)
    assert_empty preview_for(@author).creates_for(Item)
  end

  test "a remembered edit and a remembered delete are not creates" do
    # They name records that are already there. Offering them as pending rows would
    # duplicate them, and the applier writes them over the records the list is
    # already showing.
    character = characters(:character_one)
    remember_update(character, "name" => "Ariadne")
    remember_delete(characters(:character_two))

    assert_empty preview_for(@author).creates_for(Character)
  end

  test "a remembered create keeps the column that places it in its scope" do
    # The payload carries the story or scene a create belongs to as a column
    # (ADR 0020), and it is what makes the pending record describe a real place in
    # this universe rather than a free-floating name.
    remember_create("Section", "name" => "Act one", "story_id" => stories(:story_one).id)

    pending = preview_for(@author).creates_for(Section)

    assert_equal 1, pending.size
    assert_equal stories(:story_one).id, pending.first.story_id
    assert_equal @universe, UniverseScopeResolver.universe_for(pending.first)
  end

  test "a payload value no column holds is dropped rather than assigned" do
    # Tag lists and the two virtual photo writers are what the payload is *for* —
    # they are the values `record.changes` would have dropped — but none of them is
    # a column. Slicing to the model's own columns is what keeps them out, so a
    # payload describing a column that has since been renamed is dropped here too
    # rather than raising on a page the reader did not ask for.
    remember_create("Character", "name" => "Ariadne",
      "character_tag_ids" => [ character_tags(:character_tag_one).id ],
      "photo_data" => "data:image/png;base64,AAAA", "remove_photo" => "0",
      "column_that_went_away" => "x")

    record = preview_for(@author).creates_for(Character).first
    change = preview_for(@author).changes.first

    assert_equal "Ariadne", record.name
    assert_empty record.character_tag_ids,
      "a tag id list is a collection writer, and assigning it would build an association the row throws away"
    assert_equal "data:image/png;base64,AAAA", change.payload["photo_data"],
      "the values a column does not hold are the reason the payload exists, and the drafts page is where they are read"
  end

  # The panel's slice

  test "the panel shows a bounded slice and counts the rest" do
    # Each panel row resolves the record its change names, and the panel is
    # rendered on every page of the universe, so an unbounded list would put one
    # lookup per remembered change on all of them.
    (DraftPreview::PANEL_LIMIT + 3).times { |index| remember_create("Character", "name" => "Character #{index}") }
    preview = preview_for(@author)

    assert_equal DraftPreview::PANEL_LIMIT + 3, preview.count
    assert_equal DraftPreview::PANEL_LIMIT, preview.panel_changes.size
    assert_equal 3, preview.hidden_change_count
  end

  test "a draft with nothing in it has no hidden changes to announce" do
    preview = preview_for(@author)

    assert_not preview.any?
    assert_empty preview.panel_changes
    assert_equal 0, preview.hidden_change_count
  end

  private
    def preview_for(user)
      DraftPreview.new(user: user, universe: @universe)
    end

    def remember_create(type, payload = {})
      @draft.draft_changes.create!(action: "create", record_type: type,
        payload: { "universe_id" => @universe.id }.merge(payload.stringify_keys))
    end

    def remember_update(record, payload = {})
      @draft.draft_changes.create!(action: "update", record_type: record.class.name,
        record_id: record.id, payload: payload.stringify_keys,
        base_version: DraftChange.capture_base_version(record))
    end

    def remember_delete(record)
      @draft.draft_changes.create!(action: "delete", record_type: record.class.name,
        record_id: record.id, base_version: DraftChange.capture_base_version(record))
    end
end
