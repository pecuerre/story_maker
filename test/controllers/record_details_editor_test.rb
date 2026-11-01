require "test_helper"

# The Edit control on a record's own details page opens the workspace's editor
# rather than a second form. These tests pin the two halves of that contract: the
# page carries the editor's controller, modal, and prefill payload for a writer,
# and carries none of it for a guest or a read-only member. The Location page is
# the tree editor's case, so its trigger is a tree node rather than a flat-list
# modal.
class RecordDetailsEditorTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
  end

  test "a writer's details pages open the workspace editor in place" do
    sign_in_as(users(:user_one))

    flat_pages.each do |name, (record, path, scope)|
      get path

      assert_response :success, name
      assert_select ".page-actions a[href=?]", back_path(name), text: /All /
      assert_select ".page-actions button[data-action='modal-form#open'][data-modal-form-method='patch']" \
        "[data-modal-form-url=?]", path, { count: 1 },
        "#{name} must offer an Edit control that opens its own record"
      assert_select ".page-actions button[data-action='modal-form#open']",
        text: /Edit #{scope}/, count: 1
      assert_select ".page-actions button[data-action='modal-form#open'][data-modal-form-method='post']", 0,
        "#{name}'s details page must not offer the create action"

      values = serialized_values
      assert_equal record.name, values.fetch("name"), "#{name}'s editor must be prefilled from its record"
      assert_equal record.id.to_s, document.at_css("[data-action='modal-form#open'][data-modal-form-url]")
        &.attribute("data-modal-form-record-id")&.value
    end
  end

  test "a writer's details page declares the JSON editor contract once" do
    sign_in_as(users(:user_one))

    flat_pages.each do |name, (_, path, scope)|
      get path

      assert_response :success, name
      assert_select "[data-controller~='modal-form'][data-modal-form-response-value='json']" \
        "[data-modal-form-model-param-value=?]", scope, { count: 1 }
      assert_select "[data-modal-form-target='modal'] [data-modal-form-target='errors'][role='alert']", 1
      assert_select "form[data-modal-form-target='form'][data-action='modal-form#save']", 1
      assert_select "input[type='submit'][data-modal-form-target='submit']", 1
    end
  end

  test "the Location details page opens the shared tree editor" do
    sign_in_as(users(:user_one))
    location = locations(:location_one)

    get universe_location_path(universe_slug: @universe.slug, id: location)

    assert_response :success
    assert_select "[data-controller~='taxonomy-tree'][data-taxonomy-tree-editable-value='true']" \
      "[data-taxonomy-tree-model-param-value='location']", 1
    assert_select "button[data-action='taxonomy-tree#edit']", text: /Edit location/, count: 1
    assert_select "[data-node-id=?][data-update-url=?]", location.id,
      universe_location_path(universe_slug: @universe.slug, id: location)

    fields = JSON.parse(document.at_css("[data-taxonomy-tree-modal-fields-value]")
      .attribute("data-taxonomy-tree-modal-fields-value").value)
    values = JSON.parse(document.at_css("[data-node-id][data-taxonomy-values]")
      .attribute("data-taxonomy-values").value)

    assert_equal fields.map { |field| field.fetch("name") }.sort, values.keys.sort,
      "the tree editor's descriptors and its prefill values must name the same fields"
    assert_equal location.description, document.at_css("[data-node-id][data-description]")
      .attribute("data-description").value
  end

  test "a guest sees no editor on a public details page" do
    sign_out

    flat_pages.each do |name, (_, path, _)|
      get path

      assert_response :success, name
      assert_select "[data-controller~='modal-form']", 0, "#{name} must not render the editor"
      assert_select "button[data-action='modal-form#open']", 0, "#{name} must not offer an Edit control"
      assert_select "[data-modal-form-target='modal']", 0, "#{name} must not render the modal"
    end

    get universe_location_path(universe_slug: @universe.slug, id: locations(:location_one))

    assert_response :success
    assert_select "[data-controller~='taxonomy-tree']", 0
    assert_select "button[data-action='taxonomy-tree#edit']", 0
  end

  test "a read-only member sees no editor on a private details page" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Read-only details",
      slug: "read-only-details", private: true)
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)
    character = private_universe.characters.create!(name: "Quiet character")
    faction = private_universe.factions.create!(name: "Quiet faction")
    item = private_universe.items.create!(name: "Quiet item")
    location = private_universe.locations.create!(name: "Quiet place")

    sign_in_as(users(:user_two))

    {
      "character" => universe_character_path(universe_slug: private_universe.slug, id: character),
      "faction" => universe_faction_path(universe_slug: private_universe.slug, id: faction),
      "item" => universe_item_path(universe_slug: private_universe.slug, id: item),
      "location" => universe_location_path(universe_slug: private_universe.slug, id: location)
    }.each do |name, path|
      get path

      assert_response :success, "#{name} must stay readable for a read-only member"
      assert_select "[data-controller~='modal-form'], [data-controller~='taxonomy-tree']", 0,
        "#{name} must not render an editor"
      assert_select "button[data-action='modal-form#open'], button[data-action='taxonomy-tree#edit']", 0,
        "#{name} must not offer an Edit control"
    end
  end

  private
    # The three flat-list records, with the page each Edit control must target and
    # the noun its label uses.
    def flat_pages
      {
        "character" => [ characters(:character_one),
          universe_character_path(universe_slug: @universe.slug, id: characters(:character_one)), "character" ],
        "faction" => [ factions(:faction_one),
          universe_faction_path(universe_slug: @universe.slug, id: factions(:faction_one)), "faction" ],
        "item" => [ items(:item_one),
          universe_item_path(universe_slug: @universe.slug, id: items(:item_one)), "item" ]
      }
    end

    def back_path(name)
      case name
      when "character" then universe_characters_path(universe_slug: @universe.slug)
      when "faction" then universe_factions_path(universe_slug: @universe.slug)
      when "item" then universe_items_path(universe_slug: @universe.slug)
      end
    end

    def serialized_values
      raw = document.at_css("[data-action='modal-form#open'][data-modal-form-url]")
        .attribute("data-modal-form-values-value").value
      JSON.parse(raw)
    end

    def document
      Nokogiri::HTML(response.body)
    end
end
