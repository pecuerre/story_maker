require "test_helper"

class SectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @story = stories(:story_one)
    @section = sections(:section_one)
    @section_type = section_types(:section_type_two)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get story_sections_url(story_slug: @story.slug)

    assert_response :success
    assert_includes response.body, "Sections"
    assert_includes response.body, "Section type"
    assert_includes response.body, story_section_path(story_slug: @story.slug, id: @section)
    assert_select "a.nav-link.active", text: "Sections"
  end

  test "should create section as json" do
    assert_difference("Section.count") do
      post story_sections_url(story_slug: @story.slug),
        params: { section: { name: "New section", description: "A description", section_type_ids: [ @section_type.id ] } },
        as: :json
    end

    assert_response :created
    assert_equal [ @section_type.id ], response.parsed_body["section_type_ids"]
    assert_equal "A description", Section.order(:id).last.description
  end

  test "should update section details as json" do
    patch story_section_url(story_slug: @story.slug, id: @section),
      params: { section: { name: "Renamed", description: "Updated", section_type_ids: [ @section_type.id ] } },
      as: :json

    assert_response :success
    @section.reload
    assert_equal [ "Renamed", "Updated", [ @section_type.id ] ], [ @section.name, @section.description, @section.section_type_ids ]
  end

  test "should update section position as json" do
    patch story_section_url(story_slug: @story.slug, id: @section),
      params: { section: { position: 0 } },
      as: :json

    assert_response :success
    assert_equal 0, @section.reload.position
  end
end