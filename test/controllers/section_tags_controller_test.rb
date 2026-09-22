require "test_helper"

class SectionTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @section_tag = section_tags(:section_tag_one)
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    # The section-tags shortcut lives in the story-scoped HOW card, so a story
    # has to be selected first for the sidebar to render it.
    get universe_story_url(universe_slug: @universe.slug, id: stories(:story_one))

    get universe_section_tags_url(universe_slug: @universe.slug)
    assert_response :success
    assert_select "h1", text: "Section Tags"
    assert_select "a.nav-link.active[href=?]", universe_section_tags_path(universe_slug: @universe.slug)
    assert_select ".taxonomy-node", 2
  end

  test "should create section_tag as json for inline editing" do
    assert_difference("SectionTag.count") do
      post universe_section_tags_url(universe_slug: @universe.slug),
        params: { section_tag: { name: "Inline tag", parent_id: @section_tag.id } },
        as: :json
    end

    assert_response :created
    assert_equal "Inline tag", response.parsed_body["name"]
    assert_equal @section_tag.id, response.parsed_body["parent_id"]
  end

  test "should update section_tag as json for inline editing" do
    patch universe_section_tag_url(universe_slug: @universe.slug, id: @section_tag),
      params: { section_tag: { name: "Inline rename", description: "Inline description" } },
      as: :json

    assert_response :success
    assert_equal "Inline rename", response.parsed_body["name"]
    assert_equal "Inline description", response.parsed_body["description"]
    assert_nil @section_tag.reload.parent_id
  end

  test "should destroy section_tag as json" do
    assert_difference("SectionTag.count", -1) do
      delete universe_section_tag_url(universe_slug: @universe.slug, id: @section_tag), as: :json
    end

    assert_response :no_content
  end

  test "can move a section tag to another parent as json" do
    parent = SectionTag.create!(universe: @universe, name: "Parent")

    patch universe_section_tag_url(universe_slug: @universe.slug, id: @section_tag),
      params: { section_tag: { parent_id: parent.id } },
      as: :json

    assert_response :success
    assert_equal parent, @section_tag.reload.parent
  end

  test "can move a section tag to a position among siblings" do
    parent = SectionTag.create!(universe: @universe, name: "Parent")
    first = SectionTag.create!(universe: @universe, name: "First", parent: parent, position: 0)
    second = SectionTag.create!(universe: @universe, name: "Second", parent: parent, position: 1)

    patch universe_section_tag_url(universe_slug: @universe.slug, id: second),
      params: { section_tag: { position: 0 } },
      as: :json

    assert_response :success
    assert_equal [ second, first ], parent.children.reload.to_a
    assert_equal 0, second.reload.position
    assert_equal 1, first.reload.position
  end
end
