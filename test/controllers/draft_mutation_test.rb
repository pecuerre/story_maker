require "test_helper"

# `DraftMutation` is the only thing standing between a draft-based universe and a
# write that has already happened, and **no callback can enforce it**: the concern
# is called from inside each action, because that is the one point where a
# controller holds both the record it would have written and the attributes it was
# going to write with them. A controller that forgot the call would write straight
# through and nothing else would notice.
#
# So this file is that something else. It walks **every** mutation controller in
# both modes — twenty of them, across the JSON-only flow, the HTML flow, and both
# scopes — and asserts the single thing that differs between them: in `direct` a
# mutation writes, and in a draft-based universe it does not. The table is the
# contract; the tests below it are the details that the table cannot express,
# because one row cannot also say what a remembered payload contains.
class DraftMutationTest < ActionDispatch::IntegrationTest
  # The values the table writes. A remembered change stores what was submitted,
  # so these two strings are what the payload assertions look for.
  NEW = "Remembered by a draft"
  RENAMED = "Renamed by a draft"

  # Every mutation controller, with everything a request needs to exercise create,
  # update, and destroy against it.
  #
  #   `json`    — the controller's own response flow, which a remembered change
  #               keeps: a JSON workspace answers JSON, an HTML one redirects.
  #   `label`   — the permitted attribute carrying the text this case changes.
  #   `scope`   — the column a remembered **create** must place the record with,
  #               because the submitted payload alone cannot say where it goes.
  #   `record`  — the record the update and the destroy act on.
  #
  # Every `url`/`payload` pair is a lambda rather than a value, because the record
  # a mutation names is often one the test has to build first: Relations and
  # Ownerships have no fixtures, and the presence links can only add a record that
  # is not linked to the scene yet.
  MUTATION_CONTROLLERS = [
    {
      name: "characters", model: Character, json: true, label: :name,
      scope: -> { [ "universe_id", @universe.id ] },
      record: -> { @character },
      create: -> { [ universe_characters_url(universe_slug: @universe.slug), { character: { name: NEW } } ] },
      update: -> { [ universe_character_url(universe_slug: @universe.slug, id: @character.id),
        { character: { name: RENAMED } } ] },
      destroy: -> { universe_character_url(universe_slug: @universe.slug, id: @character.id) }
    },
    {
      name: "locations", model: Location, json: true, label: :name,
      scope: -> { [ "universe_id", @universe.id ] },
      record: -> { @location },
      create: -> { [ universe_locations_url(universe_slug: @universe.slug), { location: { name: NEW } } ] },
      update: -> { [ universe_location_url(universe_slug: @universe.slug, id: @location.id),
        { location: { name: RENAMED } } ] },
      destroy: -> { universe_location_url(universe_slug: @universe.slug, id: @location.id) }
    },
    {
      name: "items", model: Item, json: true, label: :name,
      scope: -> { [ "universe_id", @universe.id ] },
      record: -> { @item },
      create: -> { [ universe_items_url(universe_slug: @universe.slug), { item: { name: NEW } } ] },
      update: -> { [ universe_item_url(universe_slug: @universe.slug, id: @item.id), { item: { name: RENAMED } } ] },
      destroy: -> { universe_item_url(universe_slug: @universe.slug, id: @item.id) }
    },
    {
      name: "events", model: Event, json: true, label: :title,
      scope: -> { [ "universe_id", @universe.id ] },
      record: -> { @event },
      create: -> { [ universe_events_url(universe_slug: @universe.slug), { event: { title: NEW } } ] },
      update: -> { [ universe_event_url(universe_slug: @universe.slug, id: @event.id), { event: { title: RENAMED } } ] },
      destroy: -> { universe_event_url(universe_slug: @universe.slug, id: @event.id) }
    },
    {
      name: "character_tags", model: CharacterTag, json: true, label: :name,
      scope: -> { [ "universe_id", @universe.id ] },
      record: -> { @character_tag },
      create: -> { [ universe_character_tags_url(universe_slug: @universe.slug), { character_tag: { name: NEW } } ] },
      update: -> { [ universe_character_tag_url(universe_slug: @universe.slug, id: @character_tag.id),
        { character_tag: { name: RENAMED } } ] },
      destroy: -> { universe_character_tag_url(universe_slug: @universe.slug, id: @character_tag.id) }
    },
    {
      name: "location_tags", model: LocationTag, json: true, label: :name,
      scope: -> { [ "universe_id", @universe.id ] },
      record: -> { @location_tag },
      create: -> { [ universe_location_tags_url(universe_slug: @universe.slug), { location_tag: { name: NEW } } ] },
      update: -> { [ universe_location_tag_url(universe_slug: @universe.slug, id: @location_tag.id),
        { location_tag: { name: RENAMED } } ] },
      destroy: -> { universe_location_tag_url(universe_slug: @universe.slug, id: @location_tag.id) }
    },
    {
      name: "item_tags", model: ItemTag, json: true, label: :name,
      scope: -> { [ "universe_id", @universe.id ] },
      record: -> { @item_tag },
      create: -> { [ universe_item_tags_url(universe_slug: @universe.slug), { item_tag: { name: NEW } } ] },
      update: -> { [ universe_item_tag_url(universe_slug: @universe.slug, id: @item_tag.id),
        { item_tag: { name: RENAMED } } ] },
      destroy: -> { universe_item_tag_url(universe_slug: @universe.slug, id: @item_tag.id) }
    },
    {
      name: "event_tags", model: EventTag, json: true, label: :name,
      scope: -> { [ "universe_id", @universe.id ] },
      record: -> { @event_tag },
      create: -> { [ universe_event_tags_url(universe_slug: @universe.slug), { event_tag: { name: NEW } } ] },
      update: -> { [ universe_event_tag_url(universe_slug: @universe.slug, id: @event_tag.id),
        { event_tag: { name: RENAMED } } ] },
      destroy: -> { universe_event_tag_url(universe_slug: @universe.slug, id: @event_tag.id) }
    },
    {
      name: "relation_tags", model: RelationTag, json: true, label: :name,
      scope: -> { [ "universe_id", @universe.id ] },
      record: -> { @relation_tag },
      create: -> { [ universe_relation_tags_url(universe_slug: @universe.slug), { relation_tag: { name: NEW } } ] },
      update: -> { [ universe_relation_tag_url(universe_slug: @universe.slug, id: @relation_tag.id),
        { relation_tag: { name: RENAMED } } ] },
      destroy: -> { universe_relation_tag_url(universe_slug: @universe.slug, id: @relation_tag.id) }
    },
    {
      name: "ownership_tags", model: OwnershipTag, json: true, label: :name,
      scope: -> { [ "universe_id", @universe.id ] },
      record: -> { @ownership_tag },
      create: -> { [ universe_ownership_tags_url(universe_slug: @universe.slug), { ownership_tag: { name: NEW } } ] },
      update: -> { [ universe_ownership_tag_url(universe_slug: @universe.slug, id: @ownership_tag.id),
        { ownership_tag: { name: RENAMED } } ] },
      destroy: -> { universe_ownership_tag_url(universe_slug: @universe.slug, id: @ownership_tag.id) }
    },
    {
      name: "sections", model: Section, json: true, label: :name,
      scope: -> { [ "story_id", @story.id ] },
      record: -> { @section },
      create: -> { [ universe_story_sections_url(universe_slug: @universe.slug, story_id: @story.id),
        { section: { name: NEW } } ] },
      update: -> { [ universe_story_section_url(universe_slug: @universe.slug, story_id: @story.id, id: @section.id),
        { section: { name: RENAMED } } ] },
      destroy: -> { universe_story_section_url(universe_slug: @universe.slug, story_id: @story.id, id: @section.id) }
    },
    {
      name: "section_tags", model: SectionTag, json: true, label: :name,
      scope: -> { [ "story_id", @story.id ] },
      record: -> { @section_tag },
      create: -> { [ universe_story_section_tags_url(universe_slug: @universe.slug, story_id: @story.id),
        { section_tag: { name: NEW } } ] },
      update: -> { [ universe_story_section_tag_url(universe_slug: @universe.slug, story_id: @story.id, id: @section_tag.id),
        { section_tag: { name: RENAMED } } ] },
      destroy: -> { universe_story_section_tag_url(universe_slug: @universe.slug, story_id: @story.id, id: @section_tag.id) }
    },
    {
      name: "scene_tags", model: SceneTag, json: true, label: :name,
      scope: -> { [ "story_id", @story.id ] },
      record: -> { @scene_tag },
      create: -> { [ universe_story_scene_tags_url(universe_slug: @universe.slug, story_id: @story.id),
        { scene_tag: { name: NEW } } ] },
      update: -> { [ universe_story_scene_tag_url(universe_slug: @universe.slug, story_id: @story.id, id: @scene_tag.id),
        { scene_tag: { name: RENAMED } } ] },
      destroy: -> { universe_story_scene_tag_url(universe_slug: @universe.slug, story_id: @story.id, id: @scene_tag.id) }
    },
    {
      name: "scene_elements", model: SceneElement, json: true, label: :name,
      scope: -> { [ "scene_id", @scene.id ] },
      record: -> { @scene_element },
      create: -> { [ universe_story_scene_scene_elements_url(universe_slug: @universe.slug, story_id: @story.id,
        scene_id: @scene.id), { scene_element: { kind: "narration", name: NEW } } ] },
      update: -> { [ universe_story_scene_scene_element_url(universe_slug: @universe.slug, story_id: @story.id,
        scene_id: @scene.id, id: @scene_element.id), { scene_element: { name: RENAMED } } ] },
      destroy: -> { universe_story_scene_scene_element_url(universe_slug: @universe.slug, story_id: @story.id,
        scene_id: @scene.id, id: @scene_element.id) }
    },
    {
      name: "scene_characters", model: SceneCharacter, json: true, label: :role,
      scope: -> { [ "scene_id", @scene.id ] },
      record: -> { @scene_character },
      create: -> { [ universe_story_scene_scene_characters_url(universe_slug: @universe.slug, story_id: @story.id,
        scene_id: @scene.id), { scene_character: { character_id: @unlinked_character.id, role: NEW } } ] },
      update: -> { [ universe_story_scene_scene_character_url(universe_slug: @universe.slug, story_id: @story.id,
        scene_id: @scene.id, id: @scene_character.id), { scene_character: { role: RENAMED } } ] },
      destroy: -> { universe_story_scene_scene_character_url(universe_slug: @universe.slug, story_id: @story.id,
        scene_id: @scene.id, id: @scene_character.id) }
    },
    {
      name: "scene_items", model: SceneItem, json: true, label: :role,
      scope: -> { [ "scene_id", @scene.id ] },
      record: -> { @scene_item },
      create: -> { [ universe_story_scene_scene_items_url(universe_slug: @universe.slug, story_id: @story.id,
        scene_id: @scene.id), { scene_item: { item_id: @unlinked_item.id, role: NEW } } ] },
      update: -> { [ universe_story_scene_scene_item_url(universe_slug: @universe.slug, story_id: @story.id,
        scene_id: @scene.id, id: @scene_item.id), { scene_item: { role: RENAMED } } ] },
      destroy: -> { universe_story_scene_scene_item_url(universe_slug: @universe.slug, story_id: @story.id,
        scene_id: @scene.id, id: @scene_item.id) }
    },
    {
      name: "scene_locations", model: SceneLocation, json: true, label: :role,
      scope: -> { [ "scene_id", @scene.id ] },
      record: -> { @scene_location },
      create: -> { [ universe_story_scene_scene_locations_url(universe_slug: @universe.slug, story_id: @story.id,
        scene_id: @scene.id), { scene_location: { location_id: @unlinked_location.id, role: NEW } } ] },
      update: -> { [ universe_story_scene_scene_location_url(universe_slug: @universe.slug, story_id: @story.id,
        scene_id: @scene.id, id: @scene_location.id), { scene_location: { role: RENAMED } } ] },
      destroy: -> { universe_story_scene_scene_location_url(universe_slug: @universe.slug, story_id: @story.id,
        scene_id: @scene.id, id: @scene_location.id) }
    },
    {
      name: "relations", model: Relation, json: false, label: :name,
      scope: -> { [ "universe_id", @universe.id ] },
      record: -> { @relation },
      create: -> { [ universe_relations_url(universe_slug: @universe.slug),
        { relation: { name: NEW, character1_id: @character.id, character2_id: @other_character.id } } ] },
      update: -> { [ universe_relation_url(universe_slug: @universe.slug, id: @relation.id),
        { relation: { name: RENAMED, character1_id: @character.id, character2_id: @other_character.id } } ] },
      destroy: -> { universe_relation_url(universe_slug: @universe.slug, id: @relation.id) }
    },
    {
      name: "ownerships", model: Ownership, json: false, label: :name,
      scope: -> { [ "universe_id", @universe.id ] },
      record: -> { @ownership },
      create: -> { [ universe_ownerships_url(universe_slug: @universe.slug),
        { ownership: { name: NEW, item_id: @item.id, character_id: @character.id } } ] },
      update: -> { [ universe_ownership_url(universe_slug: @universe.slug, id: @ownership.id),
        { ownership: { name: RENAMED, item_id: @item.id, character_id: @character.id } } ] },
      destroy: -> { universe_ownership_url(universe_slug: @universe.slug, id: @ownership.id) }
    },
    {
      name: "scenes", model: Scene, json: false, label: :name,
      scope: -> { [ "story_id", @story.id ] },
      record: -> { @scene },
      create: -> { [ universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id),
        { scene: { name: NEW } } ] },
      update: -> { [ universe_story_scene_url(universe_slug: @universe.slug, story_id: @story.id, id: @scene.id),
        { scene: { name: RENAMED } } ] },
      destroy: -> { universe_story_scene_url(universe_slug: @universe.slug, story_id: @story.id, id: @scene.id) }
    }
  ].freeze

  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
    @character = characters(:character_one)
    @other_character = characters(:character_two)
    @unlinked_character = characters(:character_three)
    @location = locations(:location_one)
    @item = items(:item_one)
    @event = events(:event_one)
    @section = sections(:section_one)
    @scene_element = scene_elements(:narration_one)
    @scene_character = scene_characters(:scene_character_one)
    @scene_item = scene_items(:scene_item_one)
    @scene_location = scene_locations(:scene_location_one)
    @character_tag = character_tags(:character_tag_one)
    @location_tag = location_tags(:location_tag_one)
    @item_tag = item_tags(:item_tag_one)
    @event_tag = event_tags(:event_tag_one)
    @section_tag = section_tags(:section_tag_one)
    @scene_tag = scene_tags(:scene_tag_one)
    @relation_tag = RelationTag.create!(universe: @universe, name: "Kin")
    @ownership_tag = OwnershipTag.create!(universe: @universe, name: "Held")
    # Relations and Ownerships have no fixtures, and a presence link can only be
    # added for a record the scene does not already carry.
    @relation = Relation.create!(universe: @universe, character1: @character, character2: @other_character)
    @ownership = Ownership.create!(universe: @universe, character: @character, item: @item)
    @unlinked_item = @universe.items.create!(name: "Unlinked item")
    @unlinked_location = @universe.locations.create!(name: "Unlinked location")

    sign_in_as(users(:user_one))
  end

  MUTATION_CONTROLLERS.each do |controller|
    define_method(:"test_#{controller[:name]}_writes_in_a_direct_universe") do
      collaboration_mode("direct")
      record = instance_exec(&controller[:record])

      assert_difference -> { controller[:model].count }, 1, "#{controller[:name]} must write its create" do
        mutate(:post, instance_exec(&controller[:create]), controller[:json])
      end
      assert_response(controller[:json] ? :created : :found)

      mutate(:patch, instance_exec(&controller[:update]), controller[:json])
      assert_response(controller[:json] ? :ok : :see_other)
      assert_equal RENAMED, record.reload.public_send(controller[:label]),
        "#{controller[:name]} must write its update"

      mutate(:delete, [ instance_exec(&controller[:destroy]), {} ], controller[:json])
      assert_response(controller[:json] ? :no_content : :see_other)
      assert_predicate controller[:model].with_deleted.find(record.id), :deleted?,
        "#{controller[:name]} must write its destroy"

      assert_empty Draft.all, "#{controller[:name]} must not open a draft in a direct universe"
    end

    define_method(:"test_#{controller[:name]}_is_remembered_instead_of_written_in_a_wikipedia_universe") do
      collaboration_mode("wikipedia")
      record = instance_exec(&controller[:record])
      model = controller[:model]
      label = controller[:label].to_s

      assert_no_difference -> { model.count }, "#{controller[:name]} must not write its create" do
        mutate(:post, instance_exec(&controller[:create]), controller[:json])
      end
      assert_response(controller[:json] ? :accepted : :found)

      created = last_change
      assert_equal "create", created.action
      assert_equal model.name, created.record_type
      assert_nil created.record_id, "a remembered create names no record: the id is the database's to assign"
      assert_nil created.base_version, "a record that does not exist has no version to remember"
      assert_equal NEW, created.payload[label], "a remembered create keeps what was submitted"
      scope_column, scope_id = instance_exec(&controller[:scope])
      assert_equal scope_id, created.payload[scope_column],
        "a remembered create must say which scope the record belongs to"

      mutate(:patch, instance_exec(&controller[:update]), controller[:json])
      assert_response(controller[:json] ? :accepted : :see_other)

      updated = last_change
      assert_equal "update", updated.action
      assert_equal record.id, updated.record_id
      assert_equal RENAMED, updated.payload[label]
      assert updated.base_version.present?,
        "an update that names a record must remember the version it was seen at"
      assert_not_equal RENAMED, record.reload.public_send(label),
        "#{controller[:name]} must not write its update"

      mutate(:delete, [ instance_exec(&controller[:destroy]), {} ], controller[:json])
      assert_response(controller[:json] ? :accepted : :see_other)

      deleted = last_change
      assert_equal "delete", deleted.action
      assert_equal record.id, deleted.record_id
      assert_nil deleted.payload, "a remembered delete carries nothing about the record's contents"
      assert_not record.reload.deleted?, "#{controller[:name]} must not write its destroy"

      assert_equal 1, Draft.count, "one author's changes in one universe share one draft"
      assert_equal 3, DraftChange.count
    end
  end

  # The two draft-based modes are the same code path — `Universe#draft_based?` is
  # the negation of `direct?` — so one representative controller stands in for the
  # second mode, and the model test is where the predicate itself is pinned.
  test "a github universe remembers a change instead of writing it" do
    collaboration_mode("github")

    assert_no_difference -> { Character.count } do
      post universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: NEW } }, as: :json
    end

    assert_response :accepted
    assert_equal "create", last_change.action
  end

  test "a mode the application does not know still remembers, rather than writing" do
    Universe.where(id: @universe.id).update_all(collaboration_mode: "gitlab")

    assert_no_difference -> { Character.count } do
      post universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: NEW } }, as: :json
    end

    assert_response :accepted
  end

  test "a remembered create keeps the values a column cannot hold" do
    collaboration_mode("wikipedia")

    post universe_characters_url(universe_slug: @universe.slug), params: {
      character: {
        name: NEW,
        character_tag_ids: [ @character_tag.id ],
        photo_data: "data:image/png;base64,iVBORw0KGgo=",
        remove_photo: "0"
      }
    }, as: :json

    assert_response :accepted
    payload = last_change.payload
    assert_equal [ @character_tag.id ], payload["character_tag_ids"],
      "a tag assignment is not a column, so `record.changes` would never carry it"
    assert_equal "data:image/png;base64,iVBORw0KGgo=", payload["photo_data"],
      "the cropped photo is a virtual attribute that no dirty-tracking change set carries"
    assert_equal @universe.id, payload["universe_id"]
    # Nothing the author did not submit is remembered: a column the live path owns
    # would be applied as a value to write rather than as a value to decide.
    assert_nil payload["slug"]
    assert_nil payload["position"]
  end

  test "a remembered update is stamped with a version that still compares equal" do
    collaboration_mode("wikipedia")
    stamp = DraftChange.capture_base_version(@character)

    patch universe_character_url(universe_slug: @universe.slug, id: @character.id),
      params: { character: { name: RENAMED } }, as: :json

    assert_response :accepted
    change = last_change
    assert_equal stamp, change.base_version
    # The whole point of the stamp: a change that nobody else has touched must not
    # report itself a conflict the moment it is applied. A raw `Time` here would
    # never equal this string, and every change would conflict forever.
    assert_not VersionStamp.changed?(@character.reload, change.base_version)
  end

  test "a remembered presence-link edit keeps the resolved character rather than the submitted one" do
    collaboration_mode("wikipedia")
    link = @scene_character

    patch universe_story_scene_scene_character_url(universe_slug: @universe.slug, story_id: @story.id,
      scene_id: @scene.id, id: link.id), params: { scene_character: { role: RENAMED } }, as: :json

    assert_response :accepted
    change = last_change
    assert_equal({ "role" => RENAMED }, change.payload,
      "a role-only edit must not remember the stored character as if it had been re-sent")
    assert_not_equal RENAMED, link.reload.role

    patch universe_story_scene_scene_character_url(universe_slug: @universe.slug, story_id: @story.id,
      scene_id: @scene.id, id: link.id), params: { scene_character: { character_id: @unlinked_character.id } },
      as: :json

    assert_response :accepted
    assert_equal({ "character_id" => @unlinked_character.id }, last_change.payload)
  end

  test "one author keeps one open draft per universe and a finished one is not reopened" do
    collaboration_mode("wikipedia")

    2.times do
      post universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: NEW } }, as: :json
    end

    draft = Draft.sole
    assert_equal 2, draft.draft_changes.count
    assert_equal users(:user_one), draft.user
    assert_equal @universe, draft.universe
    assert draft.open?

    # An applied draft is history. A second editing session opens a new one rather
    # than adding to what was already written to the universe.
    draft.update!(status: "applied", closed_at: Time.current)

    post universe_characters_url(universe_slug: @universe.slug),
      params: { character: { name: NEW } }, as: :json

    assert_response :accepted
    assert_equal 2, Draft.count
    assert_equal [ 2, 1 ], Draft.order(:id).map { |each| each.draft_changes.count },
      "the applied draft keeps its history, and the new session opens a draft of its own"
  end

  test "another author's changes in the same universe are never joined to this one's draft" do
    collaboration_mode("wikipedia")

    post universe_characters_url(universe_slug: @universe.slug),
      params: { character: { name: NEW } }, as: :json

    sign_out
    sign_in_as(users(:user_two))

    post universe_characters_url(universe_slug: @universe.slug),
      params: { character: { name: NEW } }, as: :json

    assert_response :accepted
    assert_equal 2, Draft.count
    assert_equal [ users(:user_one), users(:user_two) ], Draft.order(:id).map(&:user)
  end

  test "the json body says the change was remembered and identifies it" do
    collaboration_mode("wikipedia")

    patch universe_character_url(universe_slug: @universe.slug, id: @character.id),
      params: { character: { name: RENAMED } }, as: :json

    assert_response :accepted
    assert_equal true, response.parsed_body["draft"]
    change = last_change
    assert_equal change.draft_id, response.parsed_body["draft_id"]
    assert_equal(
      { "id" => change.id, "action" => "update", "record_type" => "Character", "record_id" => @character.id },
      response.parsed_body["change"]
    )
  end

  test "an html workspace redirects with the remembered sentence and the documented status" do
    collaboration_mode("wikipedia")

    patch universe_relation_url(universe_slug: @universe.slug, id: @relation.id),
      params: { relation: { name: RENAMED, character1_id: @character.id, character2_id: @other_character.id } }

    assert_response :see_other
    assert_equal I18n.t("drafts.flash.remembered"), flash[:notice]
    assert_equal "Relation", last_change.record_type
  end

  test "a remembered html mutation returns the author to the page they submitted from" do
    collaboration_mode("wikipedia")

    post universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id),
      params: { scene: { name: NEW } },
      headers: { "HTTP_REFERER" => universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id) }

    assert_response :found
    assert_redirected_to universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id)
  end

  test "a remembered html mutation without a referrer falls back to the universe" do
    collaboration_mode("wikipedia")

    delete universe_relation_url(universe_slug: @universe.slug, id: @relation.id)

    assert_response :see_other
    assert_redirected_to universe_url(universe_slug: @universe.slug)
  end

  test "a create the live path would refuse is still remembered" do
    # Validation is the apply step's job, and it runs against the live path. A
    # second answer here would be a second opinion about the same record, and the
    # author would be shown whichever one happened to run first.
    collaboration_mode("wikipedia")

    assert_no_difference -> { Character.count } do
      post universe_characters_url(universe_slug: @universe.slug), params: { character: { name: "" } }, as: :json
    end

    assert_response :accepted
    assert_equal "", last_change.payload["name"]
  end

  test "a read never opens a draft" do
    collaboration_mode("wikipedia")

    assert_no_difference -> { Draft.count } do
      get universe_characters_url(universe_slug: @universe.slug)
      get universe_character_url(universe_slug: @universe.slug, id: @character.id)
      get universe_story_scene_url(universe_slug: @universe.slug, story_id: @story.id, id: @scene.id)
    end

    assert_response :success
  end

  test "a guest cannot remember anything either" do
    collaboration_mode("wikipedia")
    sign_out

    assert_no_difference [ -> { Draft.count }, -> { Character.count } ] do
      post universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: NEW } }, as: :json
    end

    assert_redirected_to new_session_url
  end

  test "a scene move is remembered as the position it asked for" do
    collaboration_mode("wikipedia")
    target = @scene.position - 1

    assert_no_difference -> { @scene.reload.position } do
      patch move_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story.id, id: @scene.id,
        direction: "up")
    end

    assert_response :see_other
    change = last_change
    assert_equal "update", change.action
    assert_equal @scene.id, change.record_id
    assert_equal({ "position" => target }, change.payload)
  end

  test "a scene element move is remembered as the position it asked for" do
    collaboration_mode("wikipedia")
    target = @scene_element.position + 1

    assert_no_difference -> { @scene_element.reload.position } do
      patch move_universe_story_scene_scene_element_url(universe_slug: @universe.slug, story_id: @story.id,
        scene_id: @scene.id, id: @scene_element.id, direction: "down"), as: :json
    end

    assert_response :accepted
    assert_equal({ "position" => target }, last_change.payload)
  end

  test "a scene grouping is remembered as the section it asked for" do
    collaboration_mode("wikipedia")
    ungrouped = scenes(:scene_three)

    patch group_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id),
      params: { scene_id: ungrouped.id, section_id: @section.id }

    assert_response :see_other
    assert_nil ungrouped.reload.section_id, "a remembered grouping must not be written"
    change = last_change
    assert_equal ungrouped.id, change.record_id
    assert_equal({ "section_id" => @section.id }, change.payload)
  end

  test "a grouping of another story's section is still a 404, remembered or not" do
    collaboration_mode("wikipedia")
    foreign = sections(:section_alt)

    assert_no_difference -> { DraftChange.count } do
      patch group_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id),
        params: { scene_id: @scene.id, section_id: foreign.id }
    end

    assert_response :not_found
  end

  private

    def collaboration_mode(mode)
      @universe.update!(collaboration_mode: mode)
    end

    # A request built by the table: a URL and the payload to send with it.
    def mutate(verb, request, json)
      url, payload = request
      return public_send(verb, url, params: payload) unless json

      public_send(verb, url, params: payload, as: :json)
    end

    def last_change
      DraftChange.order(:id).last
    end
end
