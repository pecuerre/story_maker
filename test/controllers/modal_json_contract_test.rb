require "test_helper"

# `modal_form_controller.js` submits JSON itself, so every modal page has to
# declare which mutation contract its controller actually implements. These tests
# pin that shared contract once, for all modal workspaces:
#
# - a JSON-only page declares `json`, renders the modal error region the
#   controller fills from a 422 body, and destroys through the controller's
#   button instead of a Turbo `button_to` that has no response to follow;
# - an HTML-flow page declares `html` and keeps the browser's own submission and
#   Turbo's redirect;
# - a JSON-only endpoint refuses an HTML mutation instead of committing the write
#   and then answering 406, which is what the old HTML form submission did.
#
# The last two tests are the other half of the same boundary: what the browser is
# *handed* has to match the editor it fills. A record's serialized values and its
# editor's field names are the same list, written down twice — once by a `*_fields_json`
# helper and once by a `form_with` — and nothing else compares them. A field the
# editor renders that the serializer omits opens empty; a key the serializer
# carries that the editor does not render submits a value nobody chose. Neither
# raises, which is why they are pinned here rather than left to a reading of the
# two files. The taxonomy half needs no serializer — the descriptor list *is* the
# editor's definition — so the equivalent check is between a tree's descriptors
# and the per-node prefill values serialized beside them.
class ModalJsonContractTest < ActionDispatch::IntegrationTest
  JSON_PAGES = {
    "characters" => :universe_characters_path,
    "items" => :universe_items_path,
    "events" => :universe_events_path
  }.freeze

  HTML_PAGES = {
    "relations" => [ :universe_relations_path, :universe_relation_path, :relation ],
    "ownerships" => [ :universe_ownerships_path, :universe_ownership_path, :ownership ]
  }.freeze

  # Every flat-list editor, with the form scope whose field names its serializer
  # has to match. `Relation` and `Ownership` are created here because the
  # development fixtures carry none, so their editors would otherwise have no row
  # to carry a serialized payload.
  EDITOR_SCOPES = {
    "characters" => [ :universe_characters_path, "character" ],
    "items" => [ :universe_items_path, "item" ],
    "events" => [ :universe_events_path, "event" ],
    "relations" => [ :universe_relations_path, "relation" ],
    "ownerships" => [ :universe_ownerships_path, "ownership" ]
  }.freeze

  setup do
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
  end

  # The four Scene workspaces are story-scoped rather than universe-scoped, so
  # they are pinned by their own routes. Scene Elements are read on Scene Details
  # and mutated through the same modal; the Characters, Items, and Locations tabs
  # are their own pages.
  def scene_pages(universe_slug:, story:, scene:)
    {
      "scene details elements" => [ universe_story_scene_path(universe_slug: universe_slug, story_id: story, id: scene), "scene_element" ],
      "scene characters" => [ universe_story_scene_scene_characters_path(universe_slug: universe_slug, story_id: story, scene_id: scene), "scene_character" ],
      "scene items" => [ universe_story_scene_scene_items_path(universe_slug: universe_slug, story_id: story, scene_id: scene), "scene_item" ],
      "scene locations" => [ universe_story_scene_scene_locations_path(universe_slug: universe_slug, story_id: story, scene_id: scene), "scene_location" ]
    }
  end

  def assert_json_modal(name, model_param:)
    assert_select "[data-controller='modal-form'][data-modal-form-response-value='json']", 1,
      "#{name} must declare the JSON mutation contract"
    assert_select "[data-modal-form-target='modal'] [data-modal-form-target='errors'][role='alert']", 1,
      "#{name} must render the shared modal error region"
    assert_select "form[data-modal-form-target='form'][data-action='modal-form#save']", 1,
      "#{name} must submit through the modal controller"
    assert_select "input[type='submit'][data-modal-form-target='submit']", 1,
      "#{name} must mark the submit button so it can show the pending state"
    assert_select "[data-modal-form-model-param-value=?]", model_param, { count: 1 },
      "#{name} must scope the payload to its own model"
  end

  test "a json-only modal workspace declares the json contract and its own error region" do
    JSON_PAGES.each do |name, helper|
      get public_send(helper, universe_slug: @universe.slug)

      assert_response :success
      assert_json_modal(name, model_param: name.singularize)
    end
  end

  test "every scene workspace declares the json contract" do
    scene_pages(universe_slug: @universe.slug, story: stories(:story_one), scene: scenes(:scene_one)).each do |name, (path, model_param)|
      get path

      assert_response :success
      assert_json_modal(name, model_param: model_param)
    end
  end

  test "a json-only modal workspace destroys through the modal controller" do
    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select "button[data-action='modal-form#destroy'][data-modal-form-url=?][data-modal-form-confirm=?]",
      universe_character_path(universe_slug: @universe.slug, id: characters(:character_one)),
      "Delete “#{characters(:character_one).name}”? Its descendant characters, relations, " \
      "ownerships, tag assignments, and links to scenes will be permanently removed. Scenes and " \
      "other universe records will remain."
    assert_select "form[action=?] input[name='_method'][value='delete']", universe_character_path(universe_slug: @universe.slug, id: characters(:character_one)),
      count: 0, message: "a JSON-only row must not keep a Turbo delete form that answers 204 with no replacement"
  end

  test "an ordered json-only row moves through the controller and keeps no Turbo form" do
    story = stories(:story_one)
    scene = scenes(:scene_one)
    element = scene_elements(:narration_one)

    get universe_story_scene_path(universe_slug: @universe.slug, story_id: story, id: scene)

    assert_response :success
    assert_select "button[data-action='modal-form#move'][data-modal-form-url=?][data-modal-form-direction=?]",
      move_universe_story_scene_scene_element_path(universe_slug: @universe.slug, story_id: story,
        scene_id: scene, id: element, direction: "down"), "down"
    assert_select "button[data-action='modal-form#move'][data-modal-form-url=?]",
      move_universe_story_scene_scene_element_path(universe_slug: @universe.slug, story_id: story,
        scene_id: scene, id: scene_elements(:dialogue_one), direction: "up")
    # A JSON-only move has no Turbo form to follow, so the page must not carry a
    # `button_to` that would submit HTML to the JSON-only endpoint.
    assert_select "form[action*='/move'] input[name='_method'][value='patch']", 0,
      "a JSON-only move must not leave a Turbo form behind"
  end

  test "an html-flow modal workspace keeps the redirect flow" do
    relation = Relation.create!(universe: @universe, character1: characters(:character_one), character2: characters(:character_two))
    ownership = Ownership.create!(universe: @universe, character: characters(:character_one), item: items(:item_one))
    records = { "relations" => relation, "ownerships" => ownership }

    HTML_PAGES.each do |name, (index_helper, member_helper, _)|
      get public_send(index_helper, universe_slug: @universe.slug)

      assert_response :success
      assert_select "[data-controller='modal-form'][data-modal-form-response-value='html']", 1,
        "#{name} must declare the HTML mutation contract"
      assert_select "form[data-modal-form-target='form'][data-action]", 0,
        "#{name} must not hand its submission to the modal controller"
      assert_select "form[action=?] input[name='_method'][value='delete']",
        public_send(member_helper, universe_slug: @universe.slug, id: records.fetch(name)), 1,
        "#{name} must keep Turbo's delete form"
    end
  end

  test "a json-only endpoint refuses an html mutation instead of committing it" do
    assert_no_difference("Character.count") do
      post universe_characters_url(universe_slug: @universe.slug), params: { character: { name: "Html submit" } }
    end
    assert_response :not_acceptable

    assert_no_difference("Item.count") do
      post universe_items_url(universe_slug: @universe.slug), params: { item: { name: "Html submit" } }
    end
    assert_response :not_acceptable

    assert_no_difference("Event.count") do
      post universe_events_url(universe_slug: @universe.slug), params: { event: { title: "Html submit" } }
    end
    assert_response :not_acceptable
  end

  test "the scene element and scene character endpoints also refuse an html mutation" do
    story = stories(:story_one)
    scene = scenes(:scene_one)

    assert_no_difference("SceneElement.count") do
      post universe_story_scene_scene_elements_url(universe_slug: @universe.slug, story_id: story, scene_id: scene),
        params: { scene_element: { kind: "narration", name: "Html submit" } }
    end
    assert_response :not_acceptable

    assert_no_difference("SceneCharacter.count") do
      post universe_story_scene_scene_characters_url(universe_slug: @universe.slug, story_id: story, scene_id: scene),
        params: { scene_character: { character_id: @universe.characters.first.id } }
    end
    assert_response :not_acceptable
  end

  test "the scene item and scene location endpoints also refuse an html mutation" do
    story = stories(:story_one)
    scene = scenes(:scene_one)

    assert_no_difference("SceneItem.count") do
      post universe_story_scene_scene_items_url(universe_slug: @universe.slug, story_id: story, scene_id: scene),
        params: { scene_item: { item_id: @universe.items.first.id } }
    end
    assert_response :not_acceptable

    assert_no_difference("SceneLocation.count") do
      post universe_story_scene_scene_locations_url(universe_slug: @universe.slug, story_id: story, scene_id: scene),
        params: { scene_location: { location_id: @universe.locations.first.id } }
    end
    assert_response :not_acceptable
  end

  # Sections and Locations are mutated through the taxonomy tree, which is JSON
  # only, but neither controller carried the format guard. An HTML create
  # therefore committed the record and only then raised UnknownFormat as a 406,
  # and an HTML delete was accepted outright, because `destroy` was not even
  # wrapped in `respond_to`. Both are the commit-behind-the-error failure
  # ADR 0011 exists to prevent.
  test "the section and location endpoints refuse an html mutation instead of committing it" do
    story = stories(:story_one)
    section = sections(:section_one)
    location = locations(:location_one)

    assert_no_difference("Section.count") do
      post universe_story_sections_url(universe_slug: @universe.slug, story_id: story),
        params: { section: { name: "Html submit" } }
    end
    assert_response :not_acceptable

    assert_no_difference("Location.count") do
      post universe_locations_url(universe_slug: @universe.slug),
        params: { location: { name: "Html submit" } }
    end
    assert_response :not_acceptable

    # The delete path is the one that was accepted outright rather than merely
    # committing and then raising, so it is asserted on its own.
    assert_no_difference("Section.count") do
      delete universe_story_section_url(universe_slug: @universe.slug, story_id: story, id: section)
    end
    assert_response :not_acceptable

    assert_no_difference("Location.count") do
      delete universe_location_url(universe_slug: @universe.slug, id: location)
    end
    assert_response :not_acceptable
  end

  test "a rejected json mutation answers 422 with the error hash the modal renders" do
    post universe_characters_url(universe_slug: @universe.slug),
      params: { character: { name: "" } },
      as: :json

    assert_response :unprocessable_content
    assert_equal [ "can't be blank" ], response.parsed_body["name"]
  end

  test "a record-level rejection is keyed on base so the modal can explain it" do
    post universe_events_url(universe_slug: @universe.slug),
      params: { event: { description: "No identity at all" } },
      as: :json

    assert_response :unprocessable_content
    assert_equal [ "must have a title, a date, or a relation to another event" ], response.parsed_body["base"]
  end

  test "a blank multi-select value clears the assignment instead of leaving it" do
    character = characters(:character_one)
    assert_equal [ character_tags(:character_tag_one).id ], character.character_tag_ids

    patch universe_character_url(universe_slug: @universe.slug, id: character),
      params: { character: { name: character.name, character_tag_ids: [ "" ] } },
      as: :json

    assert_response :success
    assert_empty character.reload.character_tag_ids
  end

  test "a read-only member sees no modal, no error region, and no delete control" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Modal contract universe", slug: "modal-contract", private: true)
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)
    sign_out
    sign_in_as(users(:user_two))

    get universe_characters_path(universe_slug: private_universe.slug)

    assert_response :success
    assert_select "[data-controller='modal-form']", 0
    assert_select "[data-modal-form-target='errors']", 0
    assert_select "button[data-action='modal-form#destroy']", 0
    assert_select "[data-mutation-status]", 1, "the page-level mutation status is part of the layout, not the editor"
  end

  test "a read-only member sees the scene workspaces without any control" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Read-only scene contract", slug: "read-only-scene-contract", private: true)
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)
    story = Story.create!(universe: private_universe, name: "Private story")
    scene = story.scenes.create!(name: "Private scene")
    scene.scene_elements.create!(name: "A beat", kind: "narration")
    sign_out
    sign_in_as(users(:user_two))

    scene_pages(universe_slug: private_universe.slug, story: story, scene: scene).each do |name, (path, _)|
      get path

      assert_response :success, "#{name} must stay readable for a read-only member"
      assert_select "[data-controller='modal-form']", 0, "#{name} must not render the editor"
      assert_select "[data-modal-form-target='errors']", 0, "#{name} must not render the error region"
      assert_select "button[data-action='modal-form#open']", 0, "#{name} must not offer an add action"
      assert_select "button[data-action='modal-form#move']", 0, "#{name} must not offer a move control"
      assert_select "button[data-action='modal-form#destroy']", 0, "#{name} must not offer a delete control"
    end
  end

  test "each flat editor's form fields are exactly the keys its rows are handed" do
    Relation.create!(universe: @universe, character1: characters(:character_one), character2: characters(:character_two))
    Ownership.create!(universe: @universe, character: characters(:character_one), item: items(:item_one))

    EDITOR_SCOPES.each do |name, (index_helper, scope)|
      get public_send(index_helper, universe_slug: @universe.slug)

      assert_response :success, "#{name} index"
      # `photo_url` is the one serialized key with no field behind it: it names the
      # row's stored image so the shared photo control can show what it is about to
      # replace, and the control builds its own inputs from it.
      assert_equal serialized_row_keys(scope) - [ "photo_url" ], form_field_names(scope),
        "#{name}'s editor and its serialized values name different fields, so opening " \
        "a row either cannot prefill a control or fills one that does not exist"
    end
  end

  test "each taxonomy tree's prefill values name exactly its editor descriptors" do
    RelationTag.create!(universe: @universe, name: "Kin")
    OwnershipTag.create!(universe: @universe, name: "Held")

    taxonomy_pages.each do |name, path|
      get path

      assert_response :success, "#{name} index"
      # The tree controller builds the whole editor from the descriptors and fills
      # it from the node's own values, so the two lists have to be the same list.
      # A descriptor with no value leaves the field blank on open; a value with no
      # descriptor is prefill for a control that does not exist.
      assert_equal descriptor_names(name), node_value_names(name),
        "#{name}'s descriptors and its serialized node values name different fields"
    end
  end

  private
    # The taxonomy tree pages, with a taxonomy in each scope plus the two
    # nested-record trees, because they share the same editor contract.
    def taxonomy_pages
      story = stories(:story_one)
      universe = @universe.slug

      {
        "character tags" => universe_character_tags_path(universe_slug: universe),
        "relation tags" => universe_relation_tags_path(universe_slug: universe),
        "location tags" => universe_location_tags_path(universe_slug: universe),
        "event tags" => universe_event_tags_path(universe_slug: universe),
        "item tags" => universe_item_tags_path(universe_slug: universe),
        "ownership tags" => universe_ownership_tags_path(universe_slug: universe),
        "section tags" => universe_story_section_tags_path(universe_slug: universe, story_id: story),
        "scene tags" => universe_story_scene_tags_path(universe_slug: universe, story_id: story),
        "locations" => universe_locations_path(universe_slug: universe),
        "sections" => universe_story_sections_path(universe_slug: universe, story_id: story)
      }
    end

    # The keys the page hands the browser for its first editable row, read out of
    # the DOM rather than by calling the helper, because the contract is what the
    # browser receives rather than what Ruby returns. The trigger is the row's own
    # edit button — distinguished by the record id it carries, because the page's
    # create button is the same control with an empty payload.
    def serialized_row_keys(scope)
      raw = document.at_css(
        "button[data-action='modal-form#open'][data-modal-form-record-id][data-modal-form-values-value]"
      )&.attribute("data-modal-form-values-value")&.value

      assert raw, "no row on the page carries serialized values to prefill the #{scope} editor"

      JSON.parse(raw).keys.sort
    end

    def form_field_names(scope)
      document.css(
        "form[data-modal-form-target='form'] input[name], " \
        "form[data-modal-form-target='form'] select[name], " \
        "form[data-modal-form-target='form'] textarea[name]"
      ).filter_map { |node| node["name"][/\A#{scope}\[(.+?)\](\[\])?\z/, 1] }.uniq.sort
    end

    def descriptor_names(name)
      raw = document.at_css("[data-taxonomy-tree-modal-fields-value]")&.attribute("data-taxonomy-tree-modal-fields-value")&.value

      assert raw, "#{name} renders no editor descriptors"

      JSON.parse(raw).map { |field| field.fetch("name") }.sort
    end

    def node_value_names(name)
      raw = document.at_css("li.taxonomy-node[data-taxonomy-values]")&.attribute("data-taxonomy-values")&.value

      assert raw, "#{name} renders no node to prefill the editor from"

      JSON.parse(raw).keys.sort
    end

    def document
      Nokogiri::HTML(response.body)
    end
end
