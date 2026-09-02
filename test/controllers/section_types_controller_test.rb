require "test_helper"

class SectionTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @section_type = section_types(:one)
  end

  test "should get index" do
    get section_types_url
    assert_response :success
  end

  test "should get new" do
    get new_section_type_url
    assert_response :success
  end

  test "should create section_type" do
    assert_difference("SectionType.count") do
      post section_types_url, params: { section_type: { name: @section_type.name, parent_id: @section_type.parent_id, story_id: @section_type.story_id } }
    end

    assert_redirected_to section_type_url(SectionType.last)
  end

  test "should show section_type" do
    get section_type_url(@section_type)
    assert_response :success
  end

  test "should get edit" do
    get edit_section_type_url(@section_type)
    assert_response :success
  end

  test "should update section_type" do
    patch section_type_url(@section_type), params: { section_type: { name: @section_type.name, parent_id: @section_type.parent_id, story_id: @section_type.story_id } }
    assert_redirected_to section_type_url(@section_type)
  end

  test "should destroy section_type" do
    assert_difference("SectionType.count", -1) do
      delete section_type_url(@section_type)
    end

    assert_redirected_to section_types_url
  end
end
