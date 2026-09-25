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
    assert_select "a.sidebar-link.active[href=?]",
      universe_story_sections_path(universe_slug: @universe.slug, story_id: @story) do
      assert_select ".sidebar-link-label", text: "Sections"
      assert_select ".sidebar-count", text: "2"
    end
    assert_select "nav.content-tabs a.active[aria-current=page][href=?]",
      universe_story_sections_path(universe_slug: @universe.slug, story_id: @story)
    assert_select "nav.content-tabs a[href=?]",
      universe_story_scenes_path(universe_slug: @universe.slug, story_id: @story), text: "Scenes"
  end

  test "index only lists sections of the current story" do
    alt_tag = stories(:story_alt).section_tags.create!(name: "Alt story tag")
    stories(:story_alt).sections.create!(
      name: "Section of another story",
      section_tags: [ alt_tag ]
    )

    get universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)

    assert_includes response.body, "Section one"
    assert_not_includes response.body, "Section of another story"
  end

  test "index serializes only same-story parent options" do
    Section.create!(story: stories(:story_alt), name: "Other story section")

    get universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_includes response.body, "Section one"
    assert_includes response.body, "Section two"
    assert_not_includes response.body, "Other story section"
  end

  test "index keeps the section tree and adds a grouped scene outline" do
    get universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    # The existing tree is retained.
    assert_select ".taxonomy-tree"
    assert_select ".taxonomy-node", 2

    assert_select ".scene-grouping" do
      assert_select "h2", text: "Grouped scenes"
      assert_includes response.body, "Ungrouped"
      assert_includes response.body, "Section one / Section two"
      assert_select "a[href=?]", universe_story_scene_path(
        universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_one)
      ), text: "Scene one"
    end
  end

  test "the grouped outline shows ungrouped scenes first and keeps narrative order inside a group" do
    get universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)

    groups = css_select(".scene-grouping .list-group-item").map { |item| item.text.squish }
    ungrouped_index = groups.index { |text| text.start_with?("Ungrouped") }

    assert ungrouped_index, "expected an Ungrouped group"
    assert_includes groups[ungrouped_index], "Scene three"
  end

  test "the grouped outline offers accessible move selectors for writers only" do
    get universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)

    assert_select "form[action=?].scene-grouping-form", group_universe_story_scenes_path(
      universe_slug: @universe.slug, story_id: @story
    )
    assert_select "select[name=scene_id] option", @story.scenes.count
    assert_select "select[name=section_id] option", @story.sections.count + 1

    universe, story = private_story
    story.sections.create!(name: "Private section")
    story.scenes.create!(name: "Private scene")
    sign_in_read_only_member(universe)

    get universe_story_sections_url(universe_slug: universe.slug, story_id: story)

    assert_response :success
    assert_select ".scene-grouping", 1
    assert_select "form.scene-grouping-form", count: 0
    assert_select "select[name=scene_id]", count: 0
    assert_includes response.body, "Private scene"
  end

  test "the grouped outline shows an empty state when the story has no scenes" do
    @story.scenes.destroy_all

    get universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_select ".scene-grouping .empty-title", text: "No scenes yet"
    assert_select "form.scene-grouping-form", count: 0
    assert_select "a[href=?]", new_universe_story_scene_path(universe_slug: @universe.slug, story_id: @story)
  end

  test "the section delete confirmation states that linked scenes become ungrouped" do
    get universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)

    assert_select "li.taxonomy-node[data-confirm-message=?]",
      "Delete “Section one”? Its child sections and tag assignments will be removed, and linked " \
      "scenes will become ungrouped. Their narrative order will not change."
  end

  test "destroying a section ungroups its scenes without removing or reordering them" do
    scene = scenes(:scene_one)
    original_positions = @story.scenes.reorder(:position, :id).pluck(:position)

    assert_difference("Scene.count", 0) do
      delete universe_story_section_url(universe_slug: @universe.slug, story_id: @story, id: @section),
        as: :json
    end

    assert_response :no_content
    assert_nil scene.reload.section
    assert_equal original_positions, @story.scenes.reorder(:position, :id).pluck(:position)
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

  test "creating a section without tags leaves it untagged" do
    story = stories(:story_alt)

    assert_no_difference("SectionTag.count") do
      assert_difference("Section.count") do
        post universe_story_sections_url(universe_slug: @universe.slug, story_id: story),
          params: { section: { name: "Inline section" } },
          as: :json
      end
    end

    assert_response :created
    section = Section.order(:id).last
    assert_empty section.section_tags
    assert_empty response.parsed_body["section_tag_ids"]
  end

  test "cannot use a section tag of another story" do
    foreign_tag = section_tags(:section_tag_three)

    assert_no_difference("Section.count") do
      post universe_story_sections_url(universe_slug: @universe.slug, story_id: @story),
        params: { section: { name: "Cross-story", section_tag_ids: [ foreign_tag.id ] } },
        as: :json
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["section_tags"], "must belong to the same story"
  end

  test "should update section details as json" do
    patch universe_story_section_url(universe_slug: @universe.slug, story_id: @story, id: @section),
      params: { section: { name: "Renamed", description: "Updated", section_tag_ids: [ @section_tag.id ] } },
      as: :json

    assert_response :success
    @section.reload
    assert_equal [ "Renamed", "Updated", [ @section_tag.id ] ], [ @section.name, @section.description, @section.section_tag_ids ]
  end

  test "creates a section at the requested position in one request" do
    section_one = sections(:section_one)
    first = @story.sections.create!(name: "First sibling", position: 1)
    second = @story.sections.create!(name: "Second sibling", position: 2)

    post universe_story_sections_url(universe_slug: @universe.slug, story_id: @story),
      params: { section: { name: "Inserted sibling", position: 0 } },
      as: :json

    assert_response :created
    assert_equal 0, response.parsed_body["position"]
    inserted = Section.find_by!(name: "Inserted sibling")
    assert_equal [ inserted, section_one, first, second ], @story.sections.where(parent_id: nil).order(:position, :id).to_a
  end

  test "should update section position as json" do
    patch universe_story_section_url(universe_slug: @universe.slug, story_id: @story, id: @section),
      params: { section: { position: 0 } },
      as: :json

    assert_response :success
    assert_equal 0, @section.reload.position
  end

  test "can reparent a section through the scoped JSON editor" do
    parent = @story.sections.create!(name: "New parent", position: 1)

    patch universe_story_section_url(universe_slug: @universe.slug, story_id: @story, id: @section),
      params: { section: { parent_id: parent.id, position: 0 } },
      as: :json

    assert_response :success
    assert_equal parent, @section.reload.parent
    assert_equal 0, @section.position
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

  private
    # A read-only collaborator needs a private universe; a public universe grants
    # write access to every signed-in user.
    def private_story
      universe = Universe.create!(owner: users(:user_one), name: "Private sections", slug: "private-sections", private: true)
      [ universe, Story.create!(universe: universe, name: "Private story") ]
    end

    def sign_in_read_only_member(universe)
      UniverseMembership.create!(universe: universe, user: users(:user_two), access_level: :read)
      sign_out
      sign_in_as(users(:user_two))
    end
end
