require "test_helper"

class ScenesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
    sign_in_as(users(:user_one))
  end

  # A public universe grants write access to every signed-in user, so the
  # read-only collaborator case needs a private universe with a read membership.
  def private_story
    universe = Universe.create!(owner: users(:user_one), name: "Private scenes", slug: "private-scenes", private: true)
    [ universe, Story.create!(universe: universe, name: "Private story") ]
  end

  def sign_in_read_only_member(universe)
    UniverseMembership.create!(universe: universe, user: users(:user_two), access_level: :read)
    sign_out
    sign_in_as(users(:user_two))
  end

  test "index lists the story scenes in narrative order with writer controls" do
    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_select "h1", text: "Scenes"
    assert_select ".entity-list .entity-row", 3
    assert_select ".entity-list .entity-title" do |titles|
      assert_equal [ "Scene one", "Scene two", "Scene three" ], titles.map(&:text)
    end
    assert_select ".entity-list .badge[aria-label^=?]", "Narrative position" do |badges|
      assert_equal [ "1", "2", "3" ], badges.map { |badge| badge.text.strip }
    end
    assert_select "a[href=?]", universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)
    assert_select "a[href=?]", new_universe_story_scene_path(universe_slug: @universe.slug, story_id: @story)
    assert_select "a[href=?]", edit_universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)
    assert_select "form[action=?][method=?]",
      move_universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene), "post"
    assert_select "nav.content-tabs a.active[aria-current=page][href=?]",
      universe_story_scenes_path(universe_slug: @universe.slug, story_id: @story)
    assert_select "a.sidebar-link.active[aria-current=page][href=?]",
      universe_story_scenes_path(universe_slug: @universe.slug, story_id: @story) do
      assert_select ".sidebar-link-label", text: "Scenes"
      assert_select ".sidebar-count", text: "3"
    end
  end

  test "index labels each scene with its section path or an ungrouped indicator" do
    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    grouping_badges = css_select(".entity-row .badge").map { |badge| badge.text.squish }
    assert_includes grouping_badges, "Section one"
    assert_includes grouping_badges, "Section one / Section two"
    assert_includes grouping_badges, "Ungrouped"
  end

  test "index does not confuse section order with narrative order" do
    # A section created later still cannot reorder the sequence.
    stories(:story_one).sections.create!(name: "Later section")

    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)
    assert_select ".entity-list .entity-title" do |titles|
      assert_equal [ "Scene one", "Scene two", "Scene three" ], titles.map(&:text)
    end
  end

  test "index disables the move controls at the sequence boundaries" do
    move_url = move_universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)
    last_url = move_universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_three))

    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)

    assert_select "form[action=?] button[data-scene-move=up][disabled]", move_url, 1
    assert_select "form[action=?] button[data-scene-move=down][disabled]", move_url, 0
    assert_select "form[action=?] button[data-scene-move=up][disabled]", last_url, 0
    assert_select "form[action=?] button[data-scene-move=down][disabled]", last_url, 1
  end

  test "index only lists scenes of the current story" do
    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: stories(:story_alt))

    assert_response :success
    assert_select ".entity-list .entity-row", 1
    assert_select ".entity-title", text: "Alt scene"
  end

  test "index shows a writer empty state without mutation instructions for read-only users" do
    @story.scenes.destroy_all

    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)
    assert_response :success
    assert_select ".empty-title", text: "No scenes yet"
    assert_select ".empty-description", text: /Add the first one/
    assert_select "a[href=?]", new_universe_story_scene_path(universe_slug: @universe.slug, story_id: @story)

    universe, story = private_story
    sign_in_read_only_member(universe)

    get universe_story_scenes_url(universe_slug: universe.slug, story_id: story)
    assert_response :success
    assert_select ".empty-title", text: "No scenes yet"
    assert_select ".empty-description", text: /no scenes to show yet/i
    assert_select "a[href=?]", new_universe_story_scene_path(universe_slug: universe.slug, story_id: story), count: 0
    assert_select "form[action^=?]",
      "#{universe_story_scenes_path(universe_slug: universe.slug, story_id: story)}/", count: 0
  end

  test "index is readable by a public-universe guest and hides every mutation control" do
    sign_out

    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_select ".entity-list .entity-row", 3
    assert_select "a[href=?]", new_universe_story_scene_path(universe_slug: @universe.slug, story_id: @story), count: 0
    assert_select "a[href^=?]",
      edit_universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene), count: 0
    assert_select "form[action^=?]",
      move_universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene), count: 0
  end

  test "guests are sent to sign in before mutating a public universe" do
    sign_out

    assert_no_difference("Scene.count") do
      post universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
        params: { scene: { name: "Guest scene" } }
    end

    assert_redirected_to new_session_url
  end

  test "read-only members cannot create, update, move, or destroy scenes" do
    universe, story = private_story
    scene = story.scenes.create!(name: "Private scene", description: "Only members see this")
    read_only = users(:user_two)
    UniverseMembership.create!(universe: universe, user: read_only, access_level: :read)
    sign_out
    sign_in_as(read_only)

    assert_no_difference("Scene.count") do
      post universe_story_scenes_url(universe_slug: universe.slug, story_id: story),
        params: { scene: { name: "Read-only scene" } }
    end
    assert_response :forbidden

    patch universe_story_scene_url(universe_slug: universe.slug, story_id: story, id: scene),
      params: { scene: { name: "Renamed" } }
    assert_response :forbidden

    patch move_universe_story_scene_url(universe_slug: universe.slug, story_id: story, id: scene),
      params: { direction: "down" }
    assert_response :forbidden

    assert_no_difference("Scene.count") do
      delete universe_story_scene_url(universe_slug: universe.slug, story_id: story, id: scene)
    end
    assert_response :forbidden

    assert_equal "Private scene", scene.reload.name
  end

  test "private universe scenes stay hidden from non-members and guests" do
    universe, story = private_story
    story.scenes.create!(name: "Private scene")

    sign_in_as(users(:user_two))

    get universe_story_scenes_url(universe_slug: universe.slug, story_id: story)
    assert_response :not_found

    sign_out
    get universe_story_scenes_url(universe_slug: universe.slug, story_id: story)
    assert_response :not_found

    sign_in_as(users(:user_one))
    get universe_story_scenes_url(universe_slug: universe.slug, story_id: story)
    assert_response :success
  end

  test "a story from another universe is not found" do
    get universe_story_scenes_url(universe_slug: @universe.slug, story_id: stories(:story_two))

    assert_response :not_found
  end

  test "should show the canonical scene details page" do
    get universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene)

    assert_response :success
    assert_select "h1", text: "Scene one"
    assert_includes response.body, "The first scene of the story"
    assert_includes response.body, "Scene 1 of 3 in the order Story One is told"
    assert_select "a[href=?]", universe_story_scenes_path(universe_slug: @universe.slug, story_id: @story)
    assert_select "a[href=?]", edit_universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)
    assert_select "form[action=?]", universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene), count: 0
  end

  test "scene details separates narrative order from in-world time" do
    get universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene)

    assert_response :success
    assert_select ".page-eyebrow", text: "Narrative position"
    assert_select ".page-eyebrow", text: "In-world time"
    assert_select ".page-eyebrow", text: "In-world event"
    assert_includes response.body, "2026-09-11 09:00"
    assert_includes response.body, events(:event_one).display_string
    assert_includes response.body, "Narrative order is not in-world chronology"
    assert_includes response.body, "independent values"
  end

  test "scene details states when a scene has no event or in-world time" do
    get universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_three))

    assert_response :success
    assert_includes response.body, "No event linked yet."
    assert_select ".page-eyebrow", text: "In-world time"
  end

  test "scene details links a grouped scene to its section and marks an ungrouped scene" do
    get universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_two))

    assert_select "a[href=?]", universe_story_sections_path(universe_slug: @universe.slug, story_id: @story),
      text: "Section one / Section two"

    get universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_three))

    assert_includes response.body, "Ungrouped."
  end

  test "scene details renders the url-backed workspace tab shell" do
    get universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene)

    assert_select "nav.content-tabs[aria-label=?]", "Scene workspace" do
      assert_select "a.active[aria-current=page][href=?]",
        universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene),
        text: "Scene Details"
      # Not-yet-routable tabs stay aria-disabled placeholders, never dead links.
      assert_select "a", count: 1
      %w[Characters Items Locations].each do |label|
        assert_select "span.nav-link.disabled[aria-disabled=true]", text: label
      end
    end
  end

  test "the scene editor also renders the workspace tab shell" do
    get edit_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene)

    assert_response :success
    assert_select "nav.content-tabs[aria-label=?] a.active[aria-current=page]", "Scene workspace",
      text: "Scene Details"
  end

  test "show renders an inspectable page for read-only users without controls" do
    universe, story = private_story
    scene = story.scenes.create!(name: "Private scene", description: "Only members see this")
    sign_in_read_only_member(universe)

    get universe_story_scene_url(universe_slug: universe.slug, story_id: story, id: scene)

    assert_response :success
    assert_select "h1", text: "Private scene"
    assert_includes response.body, "Only members see this"
    assert_select "form[action=?]", universe_story_scene_path(universe_slug: universe.slug, story_id: story, id: scene), count: 0
    assert_select "a[href=?]", edit_universe_story_scene_path(universe_slug: universe.slug, story_id: story, id: scene), count: 0
  end

  test "should get new" do
    get new_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_select "h1", text: "New scene"
    assert_select "form[action=?]", universe_story_scenes_path(universe_slug: @universe.slug, story_id: @story)
  end

  test "should create scene and redirect to the canonical destination" do
    assert_difference("Scene.count") do
      post universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
        params: { scene: { name: "A new scene", description: "Appended to the narrative order" } }
    end

    created = @story.scenes.find_by!(name: "A new scene")
    assert_redirected_to universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: created)
    assert_equal 3, created.position
    assert_equal [ 0, 1, 2, 3 ], @story.scenes.reorder(:position, :id).pluck(:position)
  end

  test "should create a title-only scene" do
    assert_difference("Scene.count") do
      post universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
        params: { scene: { name: "Unfinished scene", description: "" } }
    end

    assert_response :redirect
    created = @story.scenes.find_by!(name: "Unfinished scene")
    assert_nil created.section
    assert_nil created.event
    assert_nil created.datetime
    assert_predicate created.description, :blank?
  end

  test "should create a scene with a section, an event, and an in-world time" do
    assert_difference("Scene.count") do
      post universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
        params: {
          scene: {
            name: "Reference scene",
            section_id: sections(:section_two).id,
            event_id: events(:event_two).id,
            datetime: "2019-11-05T21:00"
          }
        }
    end

    created = @story.scenes.find_by!(name: "Reference scene")
    assert_redirected_to universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: created)
    assert_equal sections(:section_two), created.section
    assert_equal events(:event_two), created.event
    assert_equal Time.utc(2019, 11, 5, 21), created.datetime
  end

  test "the new and edit forms expose scoped section and event selectors" do
    get new_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_select "select[name='scene[section_id]'] option[value='']", text: "Ungrouped"
    assert_select "select[name='scene[section_id]'] option[value=?]", sections(:section_one).id,
      text: "Section one"
    assert_select "select[name='scene[section_id]'] option[value=?]", sections(:section_two).id,
      text: "— Section two"
    assert_select "select[name='scene[event_id]'] option[value='']", text: "None"
    assert_select "input[type=datetime-local][name='scene[datetime]']"

    get edit_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene)

    assert_select "select[name='scene[section_id]'] option[selected=selected][value=?]",
      sections(:section_one).id
    assert_select "input[type=datetime-local][name='scene[datetime]'][value=?]", "2026-09-11T09:00"
  end

  test "the section selector only offers sections of the current story" do
    Section.create!(story: stories(:story_alt), name: "Other story section")

    get new_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story)

    assert_includes response.body, "Section one"
    assert_not_includes response.body, "Other story section"
  end

  test "should re-render new with errors when the title is missing" do
    assert_no_difference("Scene.count") do
      post universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
        params: { scene: { name: "" } }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /Name can't be blank/
  end

  test "a malformed optional section or event id is a 422 field error, not a 500" do
    assert_no_difference("Scene.count") do
      post universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
        params: { scene: { name: "Broken references", section_id: "0", event_id: "0" } }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /Section must exist/
    assert_select ".alert-danger", text: /Event must exist/
  end

  test "a section from another story is a 422 field error" do
    assert_no_difference("Scene.count") do
      post universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
        params: { scene: { name: "Cross-story section", section_id: sections(:section_alt).id } }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /Section must belong to the same story/
  end

  test "an event from another universe is a 422 field error" do
    assert_no_difference("Scene.count") do
      post universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
        params: { scene: { name: "Cross-universe event", event_id: events(:event_other_universe).id } }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /Event must belong to the story's universe/
  end

  test "an unparseable in-world time is a 422 field error instead of being dropped" do
    post universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
      params: { scene: { name: "Bad time", datetime: "not-a-datetime" } }

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /Datetime is not a valid date and time/
    assert_select "input[type=datetime-local][name='scene[datetime]'][value=?]", "not-a-datetime"
  end

  test "should get edit" do
    get edit_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene)

    assert_response :success
    assert_select "h1", text: "Edit scene"
    assert_select "form[action=?]", universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)
    assert_select "input[name='scene[name]'][value=?]", "Scene one"
  end

  test "should update scene and redirect" do
    patch universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene),
      params: { scene: { name: "Renamed scene", description: "Updated summary" } }

    assert_redirected_to universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene)
    @scene.reload
    assert_equal [ "Renamed scene", "Updated summary" ], [ @scene.name, @scene.description ]
  end

  test "update cannot move a scene and re-renders errors instead" do
    original_position = @scene.position

    patch universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene),
      params: { scene: { name: "", position: 2 } }

    assert_response :unprocessable_content
    assert_equal original_position, @scene.reload.position
  end

  test "update changes references without touching the narrative position" do
    original_position = @scene.position

    patch universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene),
      params: {
        scene: {
          name: "Renamed scene",
          section_id: sections(:section_two).id,
          event_id: events(:event_two).id,
          datetime: "2020-02-02T08:30"
        }
      }

    assert_redirected_to universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene)
    @scene.reload
    assert_equal "Renamed scene", @scene.name
    assert_equal sections(:section_two), @scene.section
    assert_equal events(:event_two), @scene.event
    assert_equal Time.utc(2020, 2, 2, 8, 30), @scene.datetime
    assert_equal original_position, @scene.position
  end

  test "update can move a scene between sections and back to ungrouped" do
    patch universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene),
      params: { scene: { name: @scene.name, section_id: sections(:section_two).id } }
    assert_equal sections(:section_two), @scene.reload.section

    patch universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene),
      params: { scene: { name: @scene.name, section_id: "" } }
    assert_nil @scene.reload.section
  end

  test "update rejects a cross-scope section without changing the record" do
    patch universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene),
      params: { scene: { name: "Hijacked by section", section_id: sections(:section_alt).id } }

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /Section must belong to the same story/
    assert_equal "Scene one", @scene.reload.name
    assert_equal sections(:section_one), @scene.section
  end

  test "the section grouping form moves a scene and reports the new group" do
    patch group_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
      params: { scene_id: @scene.id, section_id: sections(:section_two).id }

    assert_redirected_to universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)
    assert_equal sections(:section_two), @scene.reload.section
    assert_match(/now grouped under Section one \/ Section two/, flash[:notice])
    assert_match(/narrative position did not change/, flash[:notice])
  end

  test "the section grouping form ungroups a scene" do
    patch group_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
      params: { scene_id: @scene.id, section_id: "" }

    assert_nil @scene.reload.section
    assert_match(/now ungrouped/, flash[:notice])
  end

  test "grouping never changes the narrative order" do
    original_positions = @story.scenes.reorder(:position, :id).pluck(:position)

    patch group_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
      params: { scene_id: scenes(:scene_three).id, section_id: sections(:section_one).id }

    assert_equal original_positions, @story.scenes.reorder(:position, :id).pluck(:position)
  end

  test "grouping rejects a section from another story or universe" do
    patch group_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
      params: { scene_id: @scene.id, section_id: sections(:section_alt).id }
    assert_response :not_found

    patch group_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
      params: { scene_id: @scene.id, section_id: "0" }
    assert_response :not_found

    assert_equal sections(:section_one), @scene.reload.section
  end

  test "grouping rejects a scene from another story" do
    patch group_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
      params: { scene_id: scenes(:scene_alt).id, section_id: "" }

    assert_response :not_found
  end

  test "grouping requires both a scene and a group" do
    patch group_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
      params: { scene_id: @scene.id }
    assert_response :bad_request

    patch group_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
      params: { section_id: sections(:section_one).id }
    assert_response :bad_request
  end

  test "read-only members and guests cannot group scenes" do
    universe, story = private_story
    scene = story.scenes.create!(name: "Private scene")
    target = story.sections.create!(name: "Private section")
    sign_in_read_only_member(universe)

    patch group_universe_story_scenes_url(universe_slug: universe.slug, story_id: story),
      params: { scene_id: scene.id, section_id: target.id }
    assert_response :forbidden

    sign_out
    patch group_universe_story_scenes_url(universe_slug: universe.slug, story_id: story),
      params: { scene_id: scene.id, section_id: target.id }
    assert_redirected_to new_session_url

    assert_nil scene.reload.section
  end

  test "should destroy scene and close the position gap" do
    assert_difference("Scene.count", -1) do
      delete universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene)
    end

    assert_redirected_to universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)
    assert_equal [ 0, 1 ], @story.scenes.reorder(:position, :id).pluck(:position)
  end

  test "move down reorders the narrative sequence" do
    patch move_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene),
      params: { direction: "down" }

    assert_redirected_to universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)
    assert_equal 1, @scene.reload.position
    assert_equal [ scenes(:scene_two), @scene, scenes(:scene_three) ], @story.scenes.reorder(:position, :id).to_a
    assert_equal [ 0, 1, 2 ], @story.scenes.reorder(:position, :id).pluck(:position)
  end

  test "move up reorders the narrative sequence" do
    patch move_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_three)),
      params: { direction: "up" }

    assert_response :redirect
    assert_equal 1, scenes(:scene_three).reload.position
    assert_equal [ 0, 1, 2 ], @story.scenes.reorder(:position, :id).pluck(:position)
  end

  test "moving past a sequence boundary keeps the scene in place" do
    patch move_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene),
      params: { direction: "up" }

    assert_equal 0, @scene.reload.position
    assert_match(/already first/, flash[:alert])

    last_scene = scenes(:scene_three)
    patch move_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: last_scene),
      params: { direction: "down" }

    assert_equal 2, last_scene.reload.position
    assert_match(/already last/, flash[:alert])
  end

  test "move requires a known direction" do
    patch move_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: @scene),
      params: { direction: "sideways" }

    assert_response :bad_request
    assert_equal 0, @scene.reload.position
  end

  test "cannot manage a scene through a different story or universe" do
    other_story = stories(:story_alt)

    patch universe_story_scene_url(universe_slug: @universe.slug, story_id: other_story, id: @scene),
      params: { scene: { name: "Hijacked" } }
    assert_response :not_found

    delete universe_story_scene_url(universe_slug: @universe.slug, story_id: other_story, id: @scene)
    assert_response :not_found

    patch move_universe_story_scene_url(universe_slug: @universe.slug, story_id: other_story, id: @scene),
      params: { direction: "down" }
    assert_response :not_found

    patch group_universe_story_scenes_url(universe_slug: @universe.slug, story_id: other_story),
      params: { scene_id: @scene.id, section_id: stories(:story_alt).sections.first&.id }
    assert_response :not_found

    assert_equal "Scene one", @scene.reload.name
  end
end
