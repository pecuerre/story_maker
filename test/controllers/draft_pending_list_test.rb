require "test_helper"

# What a list workspace shows about the reader's own pending changes.
#
# `DraftPreviewTest` holds the three answers the preview gives; this file is the
# other half of the slice, and the half only a rendered page can show: that every
# list carries them, that a row is **never changed to match its badge**, and that a
# universe which writes changes straight through pays nothing for asking.
#
# The nine workspaces are asserted together rather than one file each, because the
# claim being made is that the sweep is complete. A tenth workspace added later
# would render no badge and no pending row, and nothing below would notice — so the
# list of workspaces is written out here, and adding a row to it is what a new
# workspace has to do.
class DraftPendingListTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @user = users(:user_one)
    @universe.update!(collaboration_mode: "wikipedia")
    sign_in_as(@user)
    @draft = Draft.open_for!(@user, @universe)
  end

  # Every workspace, and what each one has to say

  test "every list workspace badges a record with a remembered edit" do
    # A pending edit is the case that could go wrong quietly: the row renders
    # exactly as before, so a reader who is not looking for a badge sees an
    # unchanged universe and may conclude their edit was written.
    character = characters(:character_one)
    location = locations(:location_one)
    item = items(:item_one)
    event = events(:event_one)
    section = sections(:section_one)
    scene = scenes(:scene_one)
    tag = character_tags(:character_tag_one)
    relation = Relation.create!(universe: @universe, character1: character, character2: characters(:character_two))
    ownership = Ownership.create!(universe: @universe, item: item, character: character)

    remember_edit(character, "name" => "Ariadne")
    remember_edit(location, "name" => "The Labyrinth")
    remember_edit(item, "name" => "The Thread")
    remember_edit(event, "title" => "The reckoning")
    remember_edit(section, "name" => "Act one")
    remember_edit(scene, "name" => "Arrival")
    remember_edit(tag, "name" => "Protagonist")
    remember_edit(relation, "description" => "Old friends")
    remember_edit(ownership, "description" => "Held by")

    workspaces.each do |name, path|
      get path

      assert_response :success
      assert_select "span.draft-pending-badge", text: I18n.t("drafts.pending.states.edit"), count: 1,
        message: "the #{name} workspace must badge the record the reader has a remembered edit on"
    end
  end

  test "every list workspace appends the records the draft would have created" do
    # A remembered create names no record, so the rows below are the only place in
    # the application where one is visible before it exists. Each workspace's own
    # list is where an author who just typed a name expects to find it.
    character = characters(:character_one)
    item = items(:item_one)
    tag = character_tags(:character_tag_one)

    remember_create("Character", "name" => "Pending character")
    remember_create("Item", "name" => "Pending item")
    remember_create("Event", "title" => "Pending event")
    remember_create("Relation", "character1_id" => character.id, "character2_id" => characters(:character_two).id)
    remember_create("Ownership", "character_id" => character.id, "item_id" => items(:item_one).id)
    remember_create("Location", "name" => "Pending location")
    remember_create("Section", "name" => "Pending section", "story_id" => stories(:story_one).id)
    remember_create("Scene", "name" => "Pending scene", "story_id" => stories(:story_one).id)
    remember_create("CharacterTag", "name" => "Pending tag")

    # One workspace, one remembered create of the type that workspace lists, and
    # one row for it. A Relation and an Ownership have no name of their own — their
    # endpoints are the label — so their pending rows are titled by that same
    # `record_label` a live row uses, which is the point of building the record
    # rather than printing the payload.
    expected = {
      characters: ".draft-pending-row",
      items: ".draft-pending-row",
      events: ".draft-pending-row",
      relations: ".draft-pending-row",
      ownerships: ".draft-pending-row",
      locations: ".taxonomy-pending",
      sections: ".taxonomy-pending",
      scenes: ".draft-pending-row",
      taxonomy: ".taxonomy-pending"
    }

    workspaces.each do |name, path|
      get path

      assert_response :success
      assert_select "#{expected.fetch(name)} .draft-pending-badge",
        text: I18n.t("drafts.pending.states.draft"), count: 1,
        message: "the #{name} workspace must list and badge the record the reader remembered creating"
    end
  end

  test "a pending row is titled the way a live row is" do
    # The pending row renders through `record_label`, the same ladder a live row
    # uses, so a Relation or an Ownership is still named by its endpoints rather
    # than by an empty name or by a payload id.
    character = characters(:character_one)
    remember_create("Relation", "character1_id" => character.id, "character2_id" => characters(:character_two).id)

    get universe_relations_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-row .entity-title", text: Relation.new(
      universe: @universe, character1: character, character2: characters(:character_two)
    ).display_string
  end

  test "a pending row with nothing to be called by is titled by the type it would create" do
    # A remembered create is not validated when it is remembered (ADR 0020), so the
    # row can be a record the universe would refuse to write — and one with no name
    # of its own has nothing for `record_label` to return. An Event falls back to
    # `display_label`'s last rung, which is a phrase about an id it does not have,
    # and a Character returns a blank label, so the row would carry a badge with no
    # subject or a subject that reads like a stored record.
    #
    # The row therefore says what the change *would* create, which is the sentence
    # the drafts page already gives that change. Nothing here validates the record
    # or withholds the row: whether the applier will accept it is not knowable
    # before the apply, so the row does not claim to be a record.
    remember_create("Event", "title" => "", "start_datetime" => "")
    remember_create("Character", "name" => "")
    remember_create("CharacterTag", "name" => "")

    get universe_events_path(universe_slug: @universe.slug)
    assert_response :success
    assert_select ".draft-pending-row .entity-title", text: I18n.t("drafts.show.new_record", kind: "Event")

    get universe_characters_path(universe_slug: @universe.slug)
    assert_response :success
    assert_select ".draft-pending-row .entity-title", text: I18n.t("drafts.show.new_record", kind: "Character")

    get universe_character_tags_path(universe_slug: @universe.slug)
    assert_response :success
    assert_select ".taxonomy-pending .entity-title", text: I18n.t("drafts.show.new_record", kind: "Character tag")
  end

  test "a pending row keeps the record's own name where it has one" do
    # The fallback is for a row with nothing to be called by, not a second naming
    # rule: an Event the universe *could* write is still named by its own label, so
    # the lists and the drafts page keep agreeing about what the change is about.
    remember_create("Event", "title" => "The reckoning", "start_datetime" => "1200-01-01 09:00")

    get universe_events_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-row .entity-title", text: /The reckoning/
  end

  test "a pending row is badged as a draft and carries no controls" do
    remember_create("Character", "name" => "Pending character", "description" => "Not live yet")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-row .draft-pending-badge", text: I18n.t("drafts.pending.states.draft")
    assert_select ".draft-pending-row .entity-description", text: "Not live yet"
    # There is no id to build a URL from, so a Details link or an editor here would
    # be a control that could only fail.
    assert_select ".draft-pending-row a", count: 0
    assert_select ".draft-pending-row .row-actions", count: 0
    assert_nil Character.find_by(name: "Pending character")
  end

  # The rows themselves

  test "a pending edit shows the stored values, not the remembered ones" do
    # The whole point of a "pending edit" badge is that it says *pending*. A row
    # rewritten with the author's unapplied values would be a second answer about
    # what is in the universe, and applying the draft would change the page under
    # the reader without their edit ever being saved.
    character = characters(:character_one)
    remember_edit(character, "name" => "Ariadne")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".entity-row .entity-title", text: character.name
    assert_select ".entity-row .entity-title", text: "Ariadne", count: 0
    assert_equal "Character one", character.reload.name
  end

  test "a remembered delete leaves the record in the list, badged" do
    character = characters(:character_one)
    remember_delete(character)

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".entity-row .entity-title", text: "Character one", count: 1,
      message: "the delete has not been applied, so the record is still in the universe"
    assert_select ".entity-row .draft-pending-badge", text: I18n.t("drafts.pending.states.deletion")
    assert Character.find_by(name: "Character one").present?
  end

  test "a record with both a remembered edit and a remembered delete is badged once" do
    character = characters(:character_one)
    remember_edit(character, "name" => "Ariadne")
    remember_delete(character)

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".entity-row .draft-pending-badge", count: 1
    assert_select ".entity-row .draft-pending-badge", text: I18n.t("drafts.pending.states.deletion")
  end

  test "one record's remembered change does not badge another" do
    remember_edit(characters(:character_one), "name" => "Ariadne")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    rows = Nokogiri::HTML(response.body).css(".entity-row")
    badged = rows.select { |row| row.at_css(".draft-pending-badge") }

    assert_equal 3, rows.size
    assert_equal 1, badged.size
    assert_includes badged.first.text, "Character one",
      "a change is matched by the record it names, so the badge has to land on that record's row"
  end

  # The empty states

  test "a list of nothing but a remembered create does not say there is nothing there" do
    Character.update_all(deleted_at: Time.current)
    remember_create("Character", "name" => "The first one")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-row .entity-title", text: "The first one"
    assert_select ".empty-state", count: 0,
      message: "telling a writer they have no characters while showing them one is two answers to one question"
  end

  test "an empty taxonomy tree with a remembered create shows the row and not the empty state" do
    LocationTag.update_all(deleted_at: Time.current)
    remember_create("LocationTag", "name" => "The first tag")

    get universe_tags_path(universe_slug: @universe.slug, taxonomy: "location")

    assert_response :success
    assert_select ".taxonomy-pending .entity-title", text: "The first tag"
    assert_select "[data-taxonomy-tree-empty]", count: 0
  end

  test "an empty scene list with a remembered create shows the row" do
    Scene.update_all(deleted_at: Time.current)
    remember_create("Scene", "name" => "The first scene", "story_id" => stories(:story_one).id)

    get universe_story_scenes_path(universe_slug: @universe.slug, story_id: stories(:story_one).id)

    assert_response :success
    assert_select ".draft-pending-row .entity-title", text: "The first scene"
    assert_select ".empty-state", count: 0
  end

  # Where the rows do not go

  test "a filtered scene list stays filtered" do
    # `SceneFilter` narrows the story's real scenes. A record that does not exist
    # cannot match a section, a tag, or a date range, so offering a pending row
    # beside a "nothing matched" message would answer a question nobody asked.
    remember_create("Scene", "name" => "Pending scene", "story_id" => stories(:story_one).id)

    get universe_story_scenes_path(universe_slug: @universe.slug, story_id: stories(:story_one).id,
      q: "nothing matches this")

    assert_response :success
    assert_select ".no-match, .empty-state", minimum: 1
    assert_select ".draft-pending-row .entity-title", text: "Pending scene", count: 0
  end

  test "a remembered scene that names a section is not listed as ungrouped" do
    # The ungrouped list is the Ungrouped end of the workspace. A create that
    # remembers a parent belongs on that section's own page once it exists, and
    # listing it here as well would put one future record in two places.
    remember_create("Scene", "name" => "Grouped pending scene",
      "story_id" => stories(:story_one).id, "section_id" => sections(:section_one).id)
    remember_create("Scene", "name" => "Ungrouped pending scene",
      "story_id" => stories(:story_one).id)

    get universe_story_sections_path(universe_slug: @universe.slug, story_id: stories(:story_one).id)

    assert_response :success
    assert_select "li.draft-pending-row .text-break", text: "Ungrouped pending scene", count: 1
    assert_select "li.draft-pending-row .text-break", text: "Grouped pending scene", count: 0
    # The count badge is a statement about the rows underneath it, so it has to
    # agree with them.
    assert_select ".list-group-item .badge", text: I18n.t("scenes.grouping.count", count: 2)
  end

  test "a pending create is not offered to the selectors that fill live records" do
    # The Events workspace shares one relation between its rows and its three
    # temporal pickers. A record that does not exist cannot be the event *before*
    # another one, so offering it there would be offering a link to nothing.
    remember_create("Event", "title" => "Pending event", "universe_id" => @universe.id)

    get universe_events_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select "select[name='event[before_event_id]'] option", text: "Pending event", count: 0
  end

  # Who may see any of it

  test "a universe that writes changes straight through renders neither a badge nor a panel" do
    @universe.update!(collaboration_mode: "direct")
    character = characters(:character_one)
    remember_edit(character, "name" => "Ariadne")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-badge", count: 0
    assert_select ".draft-pending-panel", count: 0
    # The entry that leads to the drafts page goes with it: there is nothing to
    # reach, because a `direct` universe never opens a draft.
    assert_select ".draft-pending-panel a[href=?]", universe_drafts_path(universe_slug: @universe.slug), count: 0
  end

  test "another reader's pending work is not rendered on a list" do
    their_draft = Draft.open_for!(users(:user_two), @universe)
    their_draft.draft_changes.create!(action: "update", record_type: "Character",
      record_id: characters(:character_one).id, payload: { "name" => "Theirs" },
      base_version: DraftChange.capture_base_version(characters(:character_one)))

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-badge", count: 0
    assert_select ".draft-pending-row", count: 0
    assert_select ".draft-pending-change", count: 0
  end

  test "a guest sees no badge, no pending row, and no panel" do
    character = characters(:character_one)
    remember_edit(character, "name" => "Ariadne")
    remember_create("Character", "name" => "Pending character")
    sign_out

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-badge", count: 0
    assert_select ".draft-pending-row", count: 0
    assert_select ".draft-pending-panel", count: 0
  end

  test "a closed draft's changes stop being reported on the lists" do
    remember_edit(characters(:character_one), "name" => "Ariadne")
    get universe_characters_path(universe_slug: @universe.slug)
    assert_select ".draft-pending-badge", count: 1

    # The draft's status is the one thing that makes a change pending or not, and
    # it is what the apply and the discard both move. A list reading closed drafts
    # would keep badging a record whose edit was either written or thrown away.
    @draft.update!(status: "applied", closed_at: Time.current)

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-badge", count: 0
  end

  private
    # The nine list workspaces, and the URL that reaches each one. The list is
    # written out rather than derived because the claim under test is that the
    # sweep is **complete**: a workspace added later would render no badge and no
    # pending row, and nothing below would notice — so adding a workspace is
    # adding a line here, and that line is what fails until the badge is wired in.
    def workspaces
      {
        characters: universe_characters_path(universe_slug: @universe.slug),
        items: universe_items_path(universe_slug: @universe.slug),
        events: universe_events_path(universe_slug: @universe.slug),
        relations: universe_relations_path(universe_slug: @universe.slug),
        ownerships: universe_ownerships_path(universe_slug: @universe.slug),
        locations: universe_locations_path(universe_slug: @universe.slug),
        sections: universe_story_sections_path(universe_slug: @universe.slug, story_id: stories(:story_one).id),
        scenes: universe_story_scenes_path(universe_slug: @universe.slug, story_id: stories(:story_one).id),
        taxonomy: universe_tags_path(universe_slug: @universe.slug, taxonomy: "character")
      }
    end

    def remember_create(type, payload = {})
      @draft.draft_changes.create!(action: "create", record_type: type,
        payload: { "universe_id" => @universe.id }.merge(payload.stringify_keys))
    end

    def remember_edit(record, payload = {})
      @draft.draft_changes.create!(action: "update", record_type: record.class.name,
        record_id: record.id, payload: payload.stringify_keys,
        base_version: DraftChange.capture_base_version(record))
    end

    def remember_delete(record)
      @draft.draft_changes.create!(action: "delete", record_type: record.class.name,
        record_id: record.id, base_version: DraftChange.capture_base_version(record))
    end
end
