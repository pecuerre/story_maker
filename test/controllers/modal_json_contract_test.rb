require "test_helper"

# `modal_form_controller.js` submits JSON itself, so every modal page has to
# declare which mutation contract its controller actually implements. These tests
# pin that shared contract once, for all five modal workspaces:
#
# - a JSON-only page declares `json`, renders the modal error region the
#   controller fills from a 422 body, and destroys through the controller's
#   button instead of a Turbo `button_to` that has no response to follow;
# - an HTML-flow page declares `html` and keeps the browser's own submission and
#   Turbo's redirect;
# - a JSON-only endpoint refuses an HTML mutation instead of committing the write
#   and then answering 406, which is what the old HTML form submission did.
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

  setup do
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
  end

  test "a json-only modal workspace declares the json contract and its own error region" do
    JSON_PAGES.each do |name, helper|
      get public_send(helper, universe_slug: @universe.slug)

      assert_response :success
      assert_select "[data-controller='modal-form'][data-modal-form-response-value='json']", 1,
        "#{name} must declare the JSON mutation contract"
      assert_select "[data-modal-form-target='modal'] [data-modal-form-target='errors'][role='alert']", 1,
        "#{name} must render the shared modal error region"
      assert_select "form[data-modal-form-target='form'][data-action='modal-form#save']", 1,
        "#{name} must submit through the modal controller"
      assert_select "input[type='submit'][data-modal-form-target='submit']", 1,
        "#{name} must mark the submit button so it can show the pending state"
    end
  end

  test "a json-only modal workspace destroys through the modal controller" do
    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select "button[data-action='modal-form#destroy'][data-modal-form-url=?][data-modal-form-confirm=?]",
      universe_character_path(universe_slug: @universe.slug, id: characters(:character_one)),
      "Delete #{characters(:character_one).name}?"
    assert_select "form[action=?] input[name='_method'][value='delete']", universe_character_path(universe_slug: @universe.slug, id: characters(:character_one)),
      count: 0, message: "a JSON-only row must not keep a Turbo delete form that answers 204 with no replacement"
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
end
