require "test_helper"

# A photo reaches the server as one ordinary form field, which is what lets the
# same control serve the JSON modals, the taxonomy editor's modal, and the plain
# full-page forms without any of them changing its mutation contract. These are
# the editor-side assertions: where the field is, what it is called, and where
# the photo a record already has comes from.
class PhotoFieldTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
  end

  # The container the crop controller takes over, and the two field names it
  # posts. `photo_data` carries the square; `remove_photo` clears the reference.
  FIELD = "[data-controller='photo-crop']"

  test "the json and html modal workspaces render the photo editor" do
    {
      "character" => :universe_characters_path,
      "item" => :universe_items_path,
      "event" => :universe_events_path,
      "relation" => :universe_relations_path,
      "ownership" => :universe_ownerships_path
    }.each do |param, helper|
      get public_send(helper, universe_slug: @universe.slug)

      assert_response :success
      assert_select "#{FIELD}[data-photo-crop-field-value=?]", "#{param}[photo_data]", 1,
        "the #{param} editor should offer the photo editor"
      assert_select "#{FIELD}[data-photo-crop-remove-field-value=?]", "#{param}[remove_photo]", 1
    end
  end

  test "the plain full-page forms render the photo editor" do
    story = stories(:story_one)
    scene = story.scenes.first

    {
      "universe" => [ edit_universe_path(universe_slug: @universe.slug) ],
      "story" => [ edit_universe_story_path(universe_slug: @universe.slug, id: story) ],
      "scene" => [ edit_universe_story_scene_path(universe_slug: @universe.slug, story_id: story, id: scene) ]
    }.each do |param, (path)|
      get path

      assert_response :success
      assert_select "#{FIELD}[data-photo-crop-field-value=?]", "#{param}[photo_data]", 1,
        "the #{param} form should offer the photo editor"
    end
  end

  test "a full-page form shows the photo the record already has" do
    story = stories(:story_one)
    story.update!(photo_data: crop)

    get edit_universe_story_path(universe_slug: @universe.slug, id: story)

    assert_response :success
    url = css_select("#{FIELD}[data-photo-crop-field-value='story[photo_data]']").first["data-photo-crop-current-url-value"]
    assert url.to_s.start_with?("/rails/active_storage/"),
      "the story editor should show the photo already stored, got #{url.inspect}"
  end

  test "a shared modal carries no photo until a row is opened" do
    # One modal form serves every row, so its field must not claim a picture of
    # its own; the row being edited supplies one when the editor opens.
    get universe_characters_path(universe_slug: @universe.slug)

    assert_response :success
    assert_select "#{FIELD}[data-photo-crop-current-url-value='']", 1
  end

  test "the universe taxonomy workspaces describe a photo editor to their modal" do
    {
      "character tags" => :universe_character_tags_path,
      "location tags" => :universe_location_tags_path,
      "item tags" => :universe_item_tags_path,
      "event tags" => :universe_event_tags_path,
      "relation tags" => :universe_relation_tags_path,
      "ownership tags" => :universe_ownership_tags_path,
      "locations" => :universe_locations_path
    }.each do |name, helper|
      get public_send(helper, universe_slug: @universe.slug)

      assert_response :success
      photo = modal_field_named("photo")
      assert_equal "photo", photo["type"], "#{name} should describe a photo editor"
      assert_equal "Photo", photo["label"]
    end
  end

  test "the story taxonomy workspaces describe a photo editor to their modal" do
    story = stories(:story_one)

    {
      "section tags" => :universe_story_section_tags_path,
      "scene tags" => :universe_story_scene_tags_path,
      "sections" => :universe_story_sections_path
    }.each do |name, helper|
      get public_send(helper, universe_slug: @universe.slug, story_id: story)

      assert_response :success
      assert_equal "photo", modal_field_named("photo")["type"], "#{name} should describe a photo editor"
    end
  end

  test "the taxonomy editor builds the same container the server renders" do
    get universe_character_tags_path(universe_slug: @universe.slug)

    assert_response :success
    assert_equal "photo", modal_field_named("photo")["name"]
    assert modal_field_named("photo")["url"],
      "the descriptor marks its value as the stored image rather than a column"
  end

  test "each taxonomy node serializes its own photo for the editor" do
    tagged = character_tags(:character_tag_one)
    tagged.update!(photo_data: crop)
    plain = character_tags(:character_tag_two)

    get universe_character_tags_path(universe_slug: @universe.slug)

    assert_response :success
    serialized = css_select("[data-taxonomy-values]").to_h do |node|
      [ node["data-node-id"], JSON.parse(node["data-taxonomy-values"]) ]
    end

    assert_match %r{\A/rails/active_storage/}, serialized.fetch(tagged.id.to_s).fetch("photo")
    assert_nil serialized.fetch(plain.id.to_s)["photo"], "a node without a photo serializes nothing"
  end

  test "a read-only member sees no photo editor anywhere" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private", slug: "private", private: true)
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)
    sign_out
    sign_in_as(users(:user_two))

    {
      "characters" => [ universe_characters_path(universe_slug: private_universe.slug) ],
      "character tags" => [ universe_character_tags_path(universe_slug: private_universe.slug) ]
    }.each do |name, (path)|
      get path

      assert_response :success
      assert_select FIELD, 0, "#{name} must not offer the editor to a read-only member"
      if name == "character tags"
        assert_nil modal_field_named("photo", required: false),
          "a read-only member has no editor at all, so the taxonomy must not describe one"
      end
    end
  end

  private
    def modal_field_named(name, required: true)
      node = css_select("[data-taxonomy-tree-modal-fields-value]").first
      return nil if node.nil?

      fields = JSON.parse(node["data-taxonomy-tree-modal-fields-value"])
      field = fields.find { |candidate| candidate["name"] == name }
      assert field, "no #{name} field in the taxonomy editor" if required
      field
    end

    def crop
      "data:image/jpeg;base64,#{Base64.strict_encode64(Rails.root.join('db/photos/dark/landscape.jpg').binread)}"
    end
end
