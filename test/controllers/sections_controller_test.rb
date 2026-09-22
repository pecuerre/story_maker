require "test_helper"

class SectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @section = sections(:section_one)
    @section_tag = section_tags(:section_tag_two)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get universe_sections_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Sections"
    assert_includes response.body, "Section tag"
    assert_includes response.body, universe_section_path(universe_slug: @universe.slug, id: @section)
    assert_select "a.nav-link.active", text: "Sections(2)"
  end

  test "should create section as json" do
    assert_difference("Section.count") do
      post universe_sections_url(universe_slug: @universe.slug),
        params: { section: { name: "New section", description: "A description", section_tag_ids: [ @section_tag.id ] } },
        as: :json
    end

    assert_response :created
    assert_equal [ @section_tag.id ], response.parsed_body["section_tag_ids"]
    assert_equal "A description", Section.order(:id).last.description
  end

  test "should update section details as json" do
    patch universe_section_url(universe_slug: @universe.slug, id: @section),
      params: { section: { name: "Renamed", description: "Updated", section_tag_ids: [ @section_tag.id ] } },
      as: :json

    assert_response :success
    @section.reload
    assert_equal [ "Renamed", "Updated", [ @section_tag.id ] ], [ @section.name, @section.description, @section.section_tag_ids ]
  end

  test "should update section position as json" do
    patch universe_section_url(universe_slug: @universe.slug, id: @section),
      params: { section: { position: 0 } },
      as: :json

    assert_response :success
    assert_equal 0, @section.reload.position
  end
end