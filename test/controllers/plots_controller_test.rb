require "test_helper"

class PlotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @plot = plots(:plot_one)
    sign_in_as(users(:user_one))
  end

  test "index lists this Story's Plots and links the full story workspace" do
    get universe_story_plots_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_select "h1", text: "Plots"
    assert_select ".sidebar-link.active[href=?]", universe_story_plots_path(
      universe_slug: @universe.slug, story_id: @story
    )
    assert_select "nav.content-tabs a[href=?]", universe_story_scenes_path(
      universe_slug: @universe.slug, story_id: @story
    ), text: "Scenes"
    assert_select "a[href=?]", universe_story_plot_path(
      universe_slug: @universe.slug, story_id: @story, id: @plot
    ), text: "Details"
    assert_select ".sidebar-count", text: "1"
  end

  test "Details lists assigned Scenes in narrative order" do
    get universe_story_plot_url(universe_slug: @universe.slug, story_id: @story, id: @plot)

    assert_response :success
    assert_select "h1", text: "Plot one"
    names = css_select(".detail-section .list-group-item a").map { |link| link.text.squish }
    assert_equal [ "Scene one", "Scene two" ], names
  end

  test "create, update, and delete use JSON and soft deletion" do
    assert_difference("Plot.count", 1) do
      post universe_story_plots_url(universe_slug: @universe.slug, story_id: @story),
        params: { plot: { name: "New arc", description: "A through-line" } }, as: :json
    end
    assert_response :created
    assert_equal "New arc", response.parsed_body["name"]
    created = @story.plots.find(response.parsed_body["id"])

    patch universe_story_plot_url(universe_slug: @universe.slug, story_id: @story, id: created),
      params: { plot: { name: "Renamed arc" } }, as: :json
    assert_response :success
    assert_equal "Renamed arc", created.reload.name

    assert_no_difference("Scene.count") do
      delete universe_story_plot_url(universe_slug: @universe.slug, story_id: @story, id: created), as: :json
    end
    assert_response :no_content
    assert_predicate Plot.with_deleted.find(created.id), :deleted?
  end

  test "HTML mutations are refused before writing" do
    assert_no_difference("Plot.count") do
      post universe_story_plots_url(universe_slug: @universe.slug, story_id: @story),
        params: { plot: { name: "HTML mutation" } }
    end
    assert_response :not_acceptable
  end

  test "a Plot from another Story is not reachable through this Story's URL" do
    patch universe_story_plot_url(universe_slug: @universe.slug, story_id: stories(:story_alt), id: @plot),
      params: { plot: { name: "Outside scope" } }, as: :json

    assert_response :not_found
    assert_not_equal "Outside scope", @plot.reload.name
  end

  test "a Scene can be assigned to a Plot and rejects a sibling-Story Plot" do
    scene = scenes(:scene_three)
    target = @story.plots.create!(name: "New through-line")

    patch universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: scene),
      params: { scene: { plot_ids: [ target.id ] } }
    assert_response :see_other
    assert_equal [ target.id ], scene.reload.plot_ids

    patch universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: scene),
      params: { scene: { plot_ids: [ plots(:plot_alt).id ] } }
    assert_response :unprocessable_content
    assert_equal [ target.id ], scene.reload.plot_ids
  end

  test "guests can read Plot pages but cannot mutate them" do
    sign_out
    get universe_story_plots_url(universe_slug: @universe.slug, story_id: @story)
    assert_response :success

    post universe_story_plots_url(universe_slug: @universe.slug, story_id: @story),
      params: { plot: { name: "Guest arc" } }, as: :json
    assert_redirected_to new_session_url
  end

  test "private-universe Plot reads and writes follow membership levels" do
    sign_out
    private_universe = Universe.create!(owner: users(:user_one), name: "Private Plot universe",
      slug: "private-plot-universe", private: true)
    private_story = Story.create!(universe: private_universe, name: "Private Plot story")
    private_plot = private_story.plots.create!(name: "Private arc")

    get universe_story_plots_url(universe_slug: private_universe.slug, story_id: private_story)
    assert_response :not_found

    sign_in_as(users(:user_two))
    get universe_story_plot_url(universe_slug: private_universe.slug, story_id: private_story, id: private_plot)
    assert_response :not_found

    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)
    get universe_story_plots_url(universe_slug: private_universe.slug, story_id: private_story)
    assert_response :success
    post universe_story_plots_url(universe_slug: private_universe.slug, story_id: private_story),
      params: { plot: { name: "Read-only attempt" } }, as: :json
    assert_response :forbidden

    UniverseMembership.find_by!(universe: private_universe, user: users(:user_two)).update!(access_level: :write)
    post universe_story_plots_url(universe_slug: private_universe.slug, story_id: private_story),
      params: { plot: { name: "Writer arc" } }, as: :json
    assert_response :created
  end

  test "the Plot workspace is translated in Spanish" do
    patch settings_url, params: { locale: "es" }
    get universe_story_plots_url(universe_slug: @universe.slug, story_id: @story)

    assert_response :success
    assert_select "title", text: /Tramas/
    assert_select "h1", text: "Tramas"
    assert_select "button", text: /Añadir trama/
    assert_select ".sidebar-link-label", text: "Tramas"
  end
end
