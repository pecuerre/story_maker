require "test_helper"

class SectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @section = sections(:section_one)
    @section_tag = section_tags(:section_tag_two)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_includes response.body, "Sections"
    assert_includes response.body, "Section tag"
    assert_includes response.body, universe_story_section_path(universe_slug: @universe.slug, story_id: @story, id: @section)
    assert_select "a.nav-link.active", text: "Sections(2)"
  end

  test "index only lists sections of the current story" do
    stories(:story_alt).sections.create!(
      name: "Section of another story",
      section_tags: [ section_tags(:section_tag_one) ]
    )

    get universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)

    assert_includes response.body, "Section one"
    assert_not_includes response.body, "Section of another story"
  end

  test "should create section as json" do
    assert_difference("Section.count") do
      post universe_story_sections_url(universe_slug: @universe.slug, story_id: @story),
        params: { section: { name: "New section", description: "A description", section_tag_ids: [ @section_tag.id ] } },
        as: :json
    end

    assert_response :created
    assert_equal [ @section_tag.id ], response.parsed_body["section_tag_ids"]
    section = Section.order(:id).last
    assert_equal "A description", section.description
    assert_equal @story, section.story
  end

  test "should update section details as json" do
    patch universe_story_section_url(universe_slug: @universe.slug, story_id: @story, id: @section),
      params: { section: { name: "Renamed", description: "Updated", section_tag_ids: [ @section_tag.id ] } },
      as: :json

    assert_response :success
    @section.reload
    assert_equal [ "Renamed", "Updated", [ @section_tag.id ] ], [ @section.name, @section.description, @section.section_tag_ids ]
  end

  test "should update section position as json" do
    patch universe_story_section_url(universe_slug: @universe.slug, story_id: @story, id: @section),
      params: { section: { position: 0 } },
      as: :json

    assert_response :success
    assert_equal 0, @section.reload.position
  end

  test "cannot manage a section through a different story" do
    other_story = stories(:story_alt)

    patch universe_story_section_url(universe_slug: @universe.slug, story_id: other_story, id: @section),
      params: { section: { name: "Hijacked" } },
      as: :json

    assert_response :not_found
    assert_not_equal "Hijacked", @section.reload.name
  end

  test "cannot reach a story belonging to another universe" do
    get universe_story_sections_url(universe_slug: @universe.slug, story_id: stories(:story_two))

    assert_response :not_found
  end
end
