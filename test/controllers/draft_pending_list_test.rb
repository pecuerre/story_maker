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
    remember_create("Character", "name" => "Pending character", "at_a_glance" => "Not live yet")

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

  # What a pending row shows of the payload beyond its columns

  test "a pending row prints the tags the author gave it" do
    # The gap finding 69 recorded: a live row in this list prints its tag badges, and
    # a pending row used to print none, so a character the author had just tagged
    # *Protagonist* appeared to have lost its tags. It goes through the same
    # `entity_tag_badge` a live row does, which is why there is one rendering path
    # rather than a second one for pending rows.
    remember_create("Character", "name" => "Pending character",
      "character_tag_ids" => [ character_tags(:character_tag_one).id ])

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-row .taxonomy-tag", text: character_tags(:character_tag_one).name
  end

  test "a pending row in a taxonomy tree prints its tags too" do
    # Locations are a tree rather than a flat list, and the tree's pending row is a
    # different partial — so the sweep has to hold on both, or the tree quietly
    # keeps the old behaviour.
    location_tag = location_tags(:location_tag_one)
    remember_create("Location", "name" => "Pending place", "location_tag_ids" => [ location_tag.id ])

    get universe_locations_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".taxonomy-pending .taxonomy-tag", text: location_tag.name
  end

  test "a pending row draws the photo the author submitted" do
    # The second half of finding 69. A photo is never on a list row, but this is the
    # one surface a submitted portrait can be seen on before the draft is applied,
    # and the drafts page states the fact in words rather than showing it.
    remember_create("Character", "name" => "Pending character",
      "photo_data" => "data:image/png;base64,#{Base64.strict_encode64("\x89PNG\r\n\x1A\n".b)}")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-row img.draft-pending-photo" do |images|
      assert_match %r{\Adata:image/png;base64,}, images.first["src"]
    end
  end

  test "a pending photo that is not an image URL never reaches the page" do
    # `photo_data` is whatever reached the controller, so a value that is not a
    # `data:` image URL must not become an `img src` — a hand-edited payload is
    # enough to try it, and the applier refusing it later is no protection at all
    # against the row that already rendered it.
    remember_create("Character", "name" => "Pending character",
      "photo_data" => "javascript:alert(1)")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-row img.draft-pending-photo", count: 0
    assert_select "img[src^='javascript']", count: 0
  end

  test "a pending row with no photo renders no image" do
    # The common case, and the one that must not leave a gap where the picture was:
    # the row is laid out the same either way rather than reserving an empty box.
    remember_create("Character", "name" => "Pending character")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-row img.draft-pending-photo", count: 0
    assert_select ".draft-pending-row .entity-title", text: "Pending character"
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

  # What the badge says beyond its state

  test "a single remembered edit says its state and nothing more" do
    # **One edit is already fully described by the state sentence**, so a count of
    # one repeats it and a lone field name answers a question nobody asked. This is
    # the case that keeps the tooltip from becoming noise on every badged row of an
    # ordinary editing session.
    remember_edit(characters(:character_one), "name" => "Ariadne")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    title = badge_title_for("Character one")
    assert_equal I18n.t("drafts.pending.states.edit_title"), title
  end

  test "a badge names the fields a remembered edit would write" do
    # **The claim a badge makes is checkable only if it says what would change.**
    # The row underneath still shows the stored values — a row is never rewritten to
    # match its badge — so "Pending edit" on its own asks the reader to trust it.
    # Naming the fields is what they can act on, and the names go through the same
    # derivation the drafts page uses, so a badge says "Character tags" where the
    # draft's own page does rather than printing `character_tag_ids`.
    character = characters(:character_one)
    remember_edit(character, "name" => "Ariadne",
      "character_tag_ids" => [ character_tags(:character_tag_one).id ])
    remember_edit(character, "name" => "Ariadne II")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    title = badge_title_for(character.name)
    assert_includes title, I18n.t("drafts.pending.states.edit_title")
    assert_includes title, I18n.t("drafts.pending.fields",
      fields: [ Character.human_attribute_name(:name),
                Character.human_attribute_name("character_tags") ].to_sentence)
  end

  test "a badge says how many remembered changes are waiting" do
    # **The other half, and the one a field list alone cannot give**: three edits on
    # one record used to carry a single badge with no way to tell whether the draft
    # held one change or three.
    character = characters(:character_one)
    remember_edit(character, "name" => "Ariadne")
    remember_edit(character, "at_a_glance" => "The thread puller")
    remember_edit(character, "character_tag_ids" => [ character_tags(:character_tag_one).id ])

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    title = badge_title_for(character.name)
    assert_includes title, I18n.t("drafts.pending.changes", count: 3)
    assert_includes title, Character.human_attribute_name(:at_a_glance)
  end

  test "a badge names the fields the author first submitted them in, once each" do
    # Two remembered edits to one column are **one field**, and a reader asking
    # "which fields would this write" wants the answer once rather than twice.
    character = characters(:character_one)
    remember_edit(character, "name" => "Ariadne", "at_a_glance" => "The thread puller")
    remember_edit(character, "name" => "Ariadne II")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    title = badge_title_for(character.name)
    assert_equal 1, title.scan(Character.human_attribute_name(:name)).size
    assert_includes title, Character.human_attribute_name(:at_a_glance)
  end

  test "a badge names at most four fields and counts the rest" do
    # **A badge is rendered on every row of every list workspace in the universe**,
    # so its reading has to be bounded for the same reason the sidebar panel's is.
    # The overflow is counted rather than dropped, so a bounded list stays a
    # complete answer.
    character = characters(:character_one)
    remember_edit(character, "name" => "Ariadne")
    remember_edit(character, "at_a_glance" => "The thread puller")
    remember_edit(character, "notes" => "A note")
    remember_edit(character, "age" => "31")
    remember_edit(character, "gender" => "woman")
    remember_edit(character, "pronouns" => "she/her")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    title = badge_title_for(character.name)
    assert_includes title, I18n.t("drafts.pending.fields_more", count: 2)
    assert_includes title, Character.human_attribute_name(:notes),
      "the fields are listed in the order the author first submitted them"
    assert_not_includes title, Character.human_attribute_name(:pronouns),
      "the fifth field and up are counted rather than named"
  end

  test "a badge never names a field for a remembered delete" do
    # **A remembered delete carries no payload at all** — it says which record and
    # which version, nothing about the contents — so there is nothing the draft
    # would write and a field sentence beside "applying the draft removes it" would
    # be inventing one. The count is still true and is still said.
    character = characters(:character_one)
    remember_edit(character, "name" => "Ariadne")
    remember_delete(character)

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    title = badge_title_for(character.name)
    assert_includes title, I18n.t("drafts.pending.states.deletion_title")
    assert_includes title, I18n.t("drafts.pending.changes", count: 2),
      "two changes really are waiting on this record, whatever the badge's state says"
    assert_not_includes title, I18n.t("drafts.pending.fields", fields: Character.human_attribute_name(:name))
  end

  test "a badge never names a field for a remembered create" do
    # A pending **create** row already shows every value the author submitted — it
    # is built from the payload and rendered through the same label ladder a live
    # row uses — so the fields would be a list of what is on the row directly above
    # the badge. The state sentence is the whole answer there.
    remember_create("Character", "name" => "Ariadne")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    title = css_select(".draft-pending-row .draft-pending-badge").first["title"]
    assert_equal I18n.t("drafts.pending.states.draft_title"), title
  end

  test "a badge on a record's own details page says the same thing as the list's" do
    # The badge is read on all twenty details pages and in every list workspace,
    # so the two are the same question asked twice. The details page passes the
    # **record** down rather than the badge's state, which is what makes this hold
    # by construction rather than by two call sites agreeing.
    character = characters(:character_one)
    remember_edit(character, "name" => "Ariadne")
    remember_edit(character, "at_a_glance" => "The thread puller")

    get universe_character_path(universe_slug: @universe.slug, id: character)
    details_title = css_select(".draft-pending-badge").first["title"]
    assert_response :success
    assert_includes details_title, I18n.t("drafts.pending.changes", count: 2)

    get universe_characters_path(universe_slug: @universe.slug)
    assert_equal details_title, badge_title_for(character.name)
  end

  test "a badge on a tag's list of tagged records names the fields too" do
    # The third surface. It is a list workspace like any other, and it is where a
    # reader asks which records carry a tag — so it inherits the same tooltip
    # rather than being the one place the answer is thin.
    character = characters(:character_one)
    tag = character_tags(:character_tag_one)
    remember_edit(character, "name" => "Ariadne")
    remember_edit(character, "at_a_glance" => "The thread puller")

    get universe_character_tag_path(universe_slug: @universe.slug, id: tag)

    assert_response :success
    assert_includes css_select(".draft-pending-badge").first["title"],
      I18n.t("drafts.pending.changes", count: 2)
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

  test "a remembered scene is listed only under the story it names" do
    # A draft belongs to a Universe, not to a Story, so one author's draft can hold
    # a Scene remembered under every story in it. A Scenes list is inside one
    # story and has to answer "what this list would hold" — and a Scene belonging
    # to a sibling story is not part of that answer. Before this, the row appeared
    # in *every* story's Scenes list with nothing on it to say where it belonged,
    # which is a list claiming a record it does not hold.
    remember_create("Scene", "name" => "Story one pending scene", "story_id" => stories(:story_one).id)

    get universe_story_scenes_path(universe_slug: @universe.slug, story_id: stories(:story_one).id)

    assert_response :success
    assert_select ".draft-pending-row .entity-title", text: "Story one pending scene", count: 1

    get universe_story_scenes_path(universe_slug: @universe.slug, story_id: stories(:story_alt).id)

    assert_response :success
    assert_select ".draft-pending-row .entity-title", text: "Story one pending scene", count: 0
  end

  test "a story's empty scene list does not claim a sibling story's pending scene" do
    # The other half of the same claim. `story_alt` has a scene of its own, so it
    # is emptied here to reach the question: telling a writer this story has no
    # scenes while a sibling story's remembered scene sat under the message would
    # be two answers to one question, and the row would be the wrong one.
    remember_create("Scene", "name" => "Story one pending scene", "story_id" => stories(:story_one).id)
    stories(:story_alt).scenes.update_all(deleted_at: Time.current)

    get universe_story_scenes_path(universe_slug: @universe.slug, story_id: stories(:story_alt).id)

    assert_response :success
    assert_select ".empty-state", count: 1
    assert_select ".draft-pending-row", count: 0
  end

  test "a remembered section is listed only under the story it names" do
    # The Sections tree is the one taxonomy drawn inside a Story, so it has to
    # narrow for the same reason the Scenes list does. `story_alt` has a section
    # of its own, so it is emptied to reach the question the empty state answers.
    remember_create("Section", "name" => "Pending section", "story_id" => stories(:story_one).id)

    get universe_story_sections_path(universe_slug: @universe.slug, story_id: stories(:story_one).id)

    assert_response :success
    assert_select ".taxonomy-pending .entity-title", text: "Pending section", count: 1

    stories(:story_alt).sections.update_all(deleted_at: Time.current)

    get universe_story_sections_path(universe_slug: @universe.slug, story_id: stories(:story_alt).id)

    assert_response :success
    assert_select ".taxonomy-pending", count: 0
    assert_select "[data-taxonomy-tree-empty]", count: 1
  end

  test "a scene tag page lists only the pending scenes its own story holds" do
    # The two story-scoped tag pages ask "which records carry this tag", and the
    # stored records they list are one story's. The leak runs this way: the tag
    # belongs to `story_alt`, and the pending scene carrying it was remembered
    # under `story_one`, so the alt page was listing a record its own story does
    # not hold.
    #
    # The alt tag is created rather than taken from the fixtures, because a
    # `SceneTag` belongs to one story and no fixture gives `story_alt` one.
    other_tag = SceneTag.create!(story: stories(:story_alt), name: "Alt scene tag", taggable: true)
    remember_create("Scene", "name" => "Story one pending scene",
      "story_id" => stories(:story_one).id, "scene_tag_ids" => [ other_tag.id ])

    get universe_story_scene_tag_path(universe_slug: @universe.slug,
      story_id: stories(:story_alt).id, id: other_tag)

    assert_response :success
    assert_select ".draft-pending-row .entity-title", text: "Story one pending scene", count: 0
  end

  test "a pending scene still reaches its own story's scene tag page" do
    # The other half: narrowing the tag pages must not drop the row they are for.
    tag = scene_tags(:scene_tag_one)
    remember_create("Scene", "name" => "Tagged pending scene",
      "story_id" => stories(:story_one).id, "scene_tag_ids" => [ tag.id ])

    get universe_story_scene_tag_path(universe_slug: @universe.slug, story_id: stories(:story_one).id, id: tag)

    assert_response :success
    assert_select ".draft-pending-row .entity-title", text: "Tagged pending scene", count: 1
  end

  test "a universe-scoped pending row is unaffected by which story the list is under" do
    # The other half of the rule. A Character's scope column is `universe_id`, which
    # no story narrows, so narrowing by story must not quietly drop a pending
    # character from a page that happens to sit inside one.
    remember_create("Character", "name" => "Pending character")

    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".draft-pending-row .entity-title", text: "Pending character", count: 1
  end

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

  test "a filtered character list stays filtered" do
    # The same rule as the Scene list, and it is decided once for every workspace
    # rather than re-decided per list: a remembered create has no id, so it cannot
    # match the text or the tag the reader filtered by.
    remember_create("Character", "name" => "Pending character")

    get universe_characters_path(universe_slug: @universe.slug, q: "nothing matches this")

    assert_response :success
    assert_select ".empty-title", text: "No characters match these filters"
    assert_select ".draft-pending-row .entity-title", text: "Pending character", count: 0
  end

  test "a character list that was only sorted still shows the reader's pending rows" do
    # An order selects nothing, so it is not a narrowing: hiding pending work
    # because a reader reordered the list would take away rows they can still act
    # on, for a filter that excluded nothing.
    remember_create("Character", "name" => "Pending character")

    get universe_characters_path(universe_slug: @universe.slug, sort: "created")

    assert_response :success
    assert_select ".empty-title", text: "No characters match these filters", count: 0
    assert_select ".draft-pending-row .entity-title", text: "Pending character", count: 1
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

    # The tooltip on the badge of the row showing `name`, which is how the tooltip
    # assertions find **their own** badge: several badged rows can share a page, and
    # "the first badge in the document" would be a badge about somebody else's record
    # the moment the sweep stops being one character.
    def badge_title_for(name)
      row = Nokogiri::HTML(response.body).css(".entity-row")
        .find { |candidate| candidate.at_css(".entity-title")&.text&.strip == name }

      assert row.present?, "expected a row titled #{name} to be on the page"

      row.at_css(".draft-pending-badge")["title"]
    end
end
