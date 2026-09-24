require "test_helper"

class SectionTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @section_tag = section_tags(:section_tag_one)
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  def section_tags_url_for(story = @story)
    universe_story_section_tags_url(universe_slug: @universe.slug, story_id: story)
  end

  def section_tag_url_for(tag, story = @story)
    universe_story_section_tag_url(universe_slug: @universe.slug, story_id: story, id: tag)
  end

  test "should get index" do
    # The story_id in the URL also selects the story the sidebar links to.
    get section_tags_url_for
    assert_response :success
    assert_select "h1", text: "Section tags"
    assert_select ".taxonomy-node", 2
  end

  test "index only lists section tags of the current story" do
    stories(:story_alt).section_tags.create!(name: "Alt story tag")

    get section_tags_url_for

    assert_includes response.body, "Section tag one"
    assert_not_includes response.body, "Alt story tag"
  end

  test "should create section_tag as json for inline editing" do
    assert_difference("SectionTag.count") do
      post section_tags_url_for,
        params: { section_tag: { name: "Inline tag", parent_id: @section_tag.id } },
        as: :json
    end

    assert_response :created
    assert_equal "Inline tag", response.parsed_body["name"]
    assert_equal @section_tag.id, response.parsed_body["parent_id"]
    created_tag = SectionTag.order(:id).last
    assert_equal @story, created_tag.story
    assert_equal universe_story_section_tag_path(universe_slug: @universe.slug, story_id: @story, id: created_tag), response.parsed_body["url"]
  end

  test "should update section_tag as json for inline editing" do
    patch section_tag_url_for(@section_tag),
      params: { section_tag: { name: "Inline rename", description: "Inline description" } },
      as: :json

    assert_response :success
    assert_equal "Inline rename", response.parsed_body["name"]
    assert_equal "Inline description", response.parsed_body["description"]
    assert_nil @section_tag.reload.parent_id
  end

  test "should destroy section_tag as json" do
    assert_difference("SectionTag.count", -1) do
      delete section_tag_url_for(@section_tag), as: :json
    end

    assert_response :no_content
  end

  test "can move a section tag to another parent as json" do
    parent = SectionTag.create!(story: @story, name: "Parent")

    patch section_tag_url_for(@section_tag),
      params: { section_tag: { parent_id: parent.id } },
      as: :json

    assert_response :success
    assert_equal parent, @section_tag.reload.parent
  end

  test "can move a section tag to a position among siblings" do
    parent = SectionTag.create!(story: @story, name: "Parent")
    first = SectionTag.create!(story: @story, name: "First", parent: parent, position: 0)
    second = SectionTag.create!(story: @story, name: "Second", parent: parent, position: 1)

    patch section_tag_url_for(second),
      params: { section_tag: { position: 0 } },
      as: :json

    assert_response :success
    assert_equal [ second, first ], parent.children.reload.to_a
    assert_equal 0, second.reload.position
    assert_equal 1, first.reload.position
  end

  test "cannot manage a section tag through a different story" do
    patch section_tag_url_for(@section_tag, stories(:story_alt)),
      params: { section_tag: { name: "Hijacked" } },
      as: :json

    assert_response :not_found
    assert_not_equal "Hijacked", @section_tag.reload.name
  end
end
