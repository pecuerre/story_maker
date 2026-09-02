require "test_helper"

class SectionTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @section_type = section_types(:one)
    @story = stories(:one)
    sign_in_as(users(:one))
  end

  test "should get index" do
    get story_section_types_url(story_slug: @story.slug)
    assert_response :success
  end

  test "should get new" do
    get new_story_section_type_url(story_slug: @story.slug)
    assert_response :success
  end

  test "should create section_type" do
    assert_difference("SectionType.count") do
      post story_section_types_url(story_slug: @story.slug), params: { section_type: { name: "New type", parent_id: nil } }
    end

    assert_redirected_to story_section_type_url(story_slug: @story.slug, id: SectionType.last)
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

  test "should show section_type" do
    get story_section_type_url(story_slug: @story.slug, id: @section_type)
    assert_response :success
  end

  test "should get edit" do
    get edit_story_section_type_url(story_slug: @story.slug, id: @section_type)
    assert_response :success
  end

  test "should update section_type" do
    patch story_section_type_url(story_slug: @story.slug, id: @section_type), params: { section_type: { name: "Renamed", parent_id: nil } }
    assert_redirected_to story_section_type_url(story_slug: @story.slug, id: @section_type)
    assert_equal "Renamed", @section_type.reload.name
  end

  test "should update section_type as json for inline editing" do
    patch story_section_type_url(story_slug: @story.slug, id: @section_type),
      params: { section_type: { name: "Inline rename" } },
      as: :json

    assert_response :success
    assert_equal "Inline rename", response.parsed_body["name"]
    assert_nil @section_type.reload.parent_id
  end

  test "should destroy section_type" do
    assert_difference("SectionType.count", -1) do
      delete story_section_type_url(story_slug: @story.slug, id: @section_type)
    end

    assert_redirected_to story_section_types_url(story_slug: @story.slug)
  end

  test "can move a section type to another parent" do
    parent = SectionType.create!(story: @story, name: "Parent")

    patch story_section_type_url(story_slug: @story.slug, id: @section_type), params: { section_type: { parent_id: parent.id } }

    assert_redirected_to story_section_type_url(story_slug: @story.slug, id: @section_type)
    assert_equal parent, @section_type.reload.parent
  end
end
