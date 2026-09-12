require "test_helper"

class SectionTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @section_type = section_types(:section_type_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get story_section_types_url(story_slug: @story.slug)
    assert_response :success
    assert_select "a.nav-link.active", text: "Section Types(2)"
  end

  test "should create section_type as json for inline editing" do
    assert_difference("SectionType.count") do
      post story_section_types_url(story_slug: @story.slug),
        params: { section_type: { name: "Inline type", parent_id: @section_type.id } },
        as: :json
    end

    assert_response :created
    assert_equal "Inline type", response.parsed_body["name"]
    assert_equal @section_type.id, response.parsed_body["parent_id"]
  end

  test "should update section_type as json for inline editing" do
    patch story_section_type_url(story_slug: @story.slug, id: @section_type),
      params: { section_type: { name: "Inline rename", description: "Inline description" } },
      as: :json

    assert_response :success
    assert_equal "Inline rename", response.parsed_body["name"]
    assert_equal "Inline description", response.parsed_body["description"]
    assert_nil @section_type.reload.parent_id
  end

  test "should destroy section_type as json" do
    assert_difference("SectionType.count", -1) do
      delete story_section_type_url(story_slug: @story.slug, id: @section_type), as: :json
    end

    assert_response :no_content
  end

  test "can move a section type to another parent as json" do
    parent = SectionType.create!(story: @story, name: "Parent")

    patch story_section_type_url(story_slug: @story.slug, id: @section_type),
      params: { section_type: { parent_id: parent.id } },
      as: :json

    assert_response :success
    assert_equal parent, @section_type.reload.parent
  end

  test "can move a section type to a position among siblings" do
    parent = SectionType.create!(story: @story, name: "Parent")
    first = SectionType.create!(story: @story, name: "First", parent: parent, position: 0)
    second = SectionType.create!(story: @story, name: "Second", parent: parent, position: 1)

    patch story_section_type_url(story_slug: @story.slug, id: second),
      params: { section_type: { position: 0 } },
      as: :json

    assert_response :success
    assert_equal [ second, first ], parent.children.reload.to_a
    assert_equal 0, second.reload.position
    assert_equal 1, first.reload.position
  end
end
