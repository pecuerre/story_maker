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
    assert_select ".entity-list .badge" do |badges|
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
    assert_predicate @story.scenes.find_by!(name: "Unfinished scene").description, :blank?
  end

  test "should re-render new with errors when the title is missing" do
    assert_no_difference("Scene.count") do
      post universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
        params: { scene: { name: "" } }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /Name can't be blank/
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

    assert_equal "Scene one", @scene.reload.name
  end
end
