require "test_helper"

# The Tropes tab is a real read page (guests and read-only members see it) whose
# mutations are JSON-only, exactly like the Characters, Items, and Locations tabs.
# It lists only the assignments the Scene carries and offers the code-owned
# catalogue through the editor's picker.
class SceneTropesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
    @path = universe_story_scene_scene_tropes_path(universe_slug: @universe.slug,
      story_id: @story, scene_id: @scene)
    sign_in_as(users(:user_one))
  end

  def private_scene
    universe = Universe.create!(owner: users(:user_one), name: "Private tropes", slug: "private-tropes", private: true)
    story = Story.create!(universe: universe, name: "Private story")
    [ universe, story, story.scenes.create!(name: "Private scene") ]
  end

  def sign_in_read_only_member(universe)
    UniverseMembership.create!(universe: universe, user: users(:user_two), access_level: :read)
    sign_out
    sign_in_as(users(:user_two))
  end

  def listed_names
    css_select(".entity-list .entity-title").map { |title| title.text.squish }
  end

  test "the tab lists only the references this scene carries" do
    get @path

    assert_response :success
    assert_equal [ "Red Herring" ], listed_names
    # The saved assignment carries the catalogue's own explanation and its note.
    assert_includes response.body, "A clue plausibly points toward a wrong explanation or suspect."
    assert_includes response.body, "This scene plants the misleading clue."
    # The rest of the catalogue is offered by the picker rather than stacked on
    # the page as cards.
    assert_select "input[type=checkbox][name*='scene_tropes_attributes']", count: 0
    assert_select ".entity-list .entity-title", text: "Chekhov’s Gun", count: 0
  end

  test "the picker offers every catalogue reference and a duplicate is refused" do
    get @path

    assert_response :success
    # The blank prompt plus every catalogue entry.
    assert_select "select[name='scene_trope[trope_slug]'] option", count: TropeCatalog.entries.size + 1
    assert_select "select[name='scene_trope[trope_slug]'] option[value='']", text: "Choose a trope"
    assert_select "select[name='scene_trope[trope_slug]'] option[value='chekhovs-gun']", text: "Chekhov’s Gun"
    # A reference already recorded is not hidden, because a stale page or a second
    # window can submit one anyway; the model reports it as an error.
    assert_select "select[name='scene_trope[trope_slug]'] option[value='red-herring']"
    assert_no_difference("SceneTrope.count") do
      post @path, params: { scene_trope: { trope_slug: "red-herring", context_note: "Again" } }, as: :json
    end
    assert_response :unprocessable_content
    assert_equal [ "has already been taken" ], response.parsed_body["trope_slug"]
  end

  test "the picker is alphabetical so a large catalogue stays browsable" do
    get @path

    assert_response :success
    names = css_select("select[name='scene_trope[trope_slug]'] option")
      .reject { |option| option["value"].blank? }
      .map { |option| option.text.squish }

    assert_equal TropeCatalog.entries.map(&:name).sort_by(&:downcase), names
    assert_equal "Bury Your Gays", names.first
  end

  test "an empty scene explains how a reference gets here" do
    empty = @story.scenes.create!(name: "Empty scene")

    get universe_story_scene_scene_tropes_path(universe_slug: @universe.slug, story_id: @story, scene_id: empty)

    assert_response :success
    assert_select ".empty-title", text: "No tropes recorded in this scene yet"
    assert_select ".empty-description", text: /The catalogue is shared by every story and scene/
  end

  test "assigns a reference with a context note" do
    assert_difference("SceneTrope.count", 1) do
      post @path, params: { scene_trope: { trope_slug: "chekhovs-gun", context_note: "The detail pays off later." } },
        as: :json
    end

    assert_response :created
    assignment = @scene.scene_tropes.order(:id).last
    assert_equal "chekhovs-gun", assignment.trope_slug
    assert_equal "The detail pays off later.", assignment.context_note
    assert_equal "chekhovs-gun", response.parsed_body["trope_slug"]
  end

  test "a blank note is stored as no note" do
    post @path, params: { scene_trope: { trope_slug: "chekhovs-gun", context_note: "" } }, as: :json

    assert_response :created
    assert_nil @scene.scene_tropes.order(:id).last.context_note
  end

  test "an unknown reference is an ordinary 422" do
    assert_no_difference("SceneTrope.count") do
      post @path, params: { scene_trope: { trope_slug: "not-in-the-catalogue" } }, as: :json
    end

    assert_response :unprocessable_content
    assert_equal [ "is not included in the list" ], response.parsed_body["trope_slug"]
  end

  test "a missing reference key is a bad request" do
    assert_no_difference("SceneTrope.count") do
      post @path, params: { scene_trope: { context_note: "No reference" } }, as: :json
    end

    assert_response :bad_request
  end

  test "a blank reference is an ordinary 422 the modal explains" do
    assert_no_difference("SceneTrope.count") do
      post @path, params: { scene_trope: { trope_slug: "", context_note: "No reference" } }, as: :json
    end

    assert_response :unprocessable_content
    assert_equal [ "can't be blank" ], response.parsed_body["trope_slug"]
  end

  test "edits the note and reports the new value" do
    assignment = scene_tropes(:scene_one_red_herring)

    patch universe_story_scene_scene_trope_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: assignment),
      params: { scene_trope: { context_note: "The clue is planted fairly." } }, as: :json

    assert_response :success
    assert_equal "The clue is planted fairly.", assignment.reload.context_note
    assert_equal "The clue is planted fairly.", response.parsed_body["context_note"]
  end

  test "clears the note by sending a blank one" do
    assignment = scene_tropes(:scene_one_red_herring)

    patch universe_story_scene_scene_trope_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: assignment), params: { scene_trope: { context_note: "  " } }, as: :json

    assert_response :success
    assert_nil assignment.reload.context_note
  end

  test "repoints an assignment at another catalogue reference" do
    assignment = scene_tropes(:scene_one_red_herring)

    patch universe_story_scene_scene_trope_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: assignment), params: { scene_trope: { trope_slug: "chekhovs-gun" } }, as: :json

    assert_response :success
    assert_equal "chekhovs-gun", assignment.reload.trope_slug
  end

  test "repointing at a reference the scene already carries is a 422" do
    SceneTrope.create!(scene: @scene, trope_slug: "chekhovs-gun")
    assignment = scene_tropes(:scene_one_red_herring)

    patch universe_story_scene_scene_trope_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: assignment), params: { scene_trope: { trope_slug: "chekhovs-gun" } }, as: :json

    assert_response :unprocessable_content
    assert_equal [ "has already been taken" ], response.parsed_body["trope_slug"]
    assert_equal "red-herring", assignment.reload.trope_slug
  end

  test "a blank reference on an update means keep the current one" do
    assignment = scene_tropes(:scene_one_red_herring)

    patch universe_story_scene_scene_trope_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: assignment), params: { scene_trope: { trope_slug: "", context_note: "stays" } }, as: :json

    assert_response :success
    assert_equal "red-herring", assignment.reload.trope_slug
    assert_equal "stays", assignment.context_note
  end

  test "an update with no editable field is a bad request" do
    assignment = scene_tropes(:scene_one_red_herring)

    patch universe_story_scene_scene_trope_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: assignment), params: { scene_trope: {} }, as: :json

    assert_response :bad_request
  end

  test "removing an assignment keeps the shared reference for every other scene" do
    assignment = scene_tropes(:scene_one_red_herring)
    other_scene = scenes(:scene_two)
    other = SceneTrope.create!(scene: other_scene, trope_slug: "red-herring")

    assert_difference("SceneTrope.count", -1) do
      delete universe_story_scene_scene_trope_path(universe_slug: @universe.slug, story_id: @story,
        scene_id: @scene, id: assignment), as: :json
    end

    assert_response :no_content
    assert SceneTrope.exists?(other.id)
    assert TropeCatalog.find("red-herring")
  end

  test "an html mutation is refused before anything is written" do
    assert_no_difference("SceneTrope.count") do
      post @path, params: { scene_trope: { trope_slug: "chekhovs-gun" } }
    end
    assert_response :not_acceptable

    assignment = scene_tropes(:scene_one_red_herring)
    patch universe_story_scene_scene_trope_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: assignment), params: { scene_trope: { context_note: "html" } }
    assert_response :not_acceptable

    assert_no_difference("SceneTrope.count") do
      delete universe_story_scene_scene_trope_path(universe_slug: @universe.slug, story_id: @story,
        scene_id: @scene, id: assignment)
    end
    assert_response :not_acceptable

    assert_equal "This scene plants the misleading clue.", assignment.reload.context_note
  end

  test "guests can read the tab and are sent to sign in to change it" do
    sign_out

    get @path

    assert_response :success
    assert_equal [ "Red Herring" ], listed_names
    assert_select "button[data-action='modal-form#open']", count: 0
    assert_select "button[data-action='modal-form#destroy']", count: 0
    assert_select "[data-modal-form-target='errors']", count: 0

    assert_no_difference("SceneTrope.count") do
      post @path, params: { scene_trope: { trope_slug: "chekhovs-gun" } }, as: :json
    end
    assert_redirected_to new_session_url
  end

  test "read-only members see the tab without any control" do
    universe, story, scene = private_scene
    assignment = scene.scene_tropes.create!(trope_slug: "found-family", context_note: "The crew builds trust.")
    sign_in_read_only_member(universe)

    get universe_story_scene_scene_tropes_path(universe_slug: universe.slug, story_id: story, scene_id: scene)

    assert_response :success
    assert_equal [ "Found Family" ], listed_names
    assert_includes response.body, "The crew builds trust."
    assert_select "button[data-action='modal-form#open']", count: 0
    assert_select "button[data-action='modal-form#destroy']", count: 0
    assert_select "[data-controller='modal-form']", count: 0

    patch universe_story_scene_scene_trope_path(universe_slug: universe.slug, story_id: story,
      scene_id: scene, id: assignment), params: { scene_trope: { context_note: "hijacked" } }, as: :json
    assert_response :forbidden

    assert_no_difference("SceneTrope.count") do
      delete universe_story_scene_scene_trope_path(universe_slug: universe.slug, story_id: story,
        scene_id: scene, id: assignment), as: :json
    end
    assert_response :forbidden

    assert_equal "The crew builds trust.", assignment.reload.context_note
  end

  test "a private universe tab stays hidden from non-members and guests" do
    universe, story, scene = private_scene

    sign_in_as(users(:user_two))
    get universe_story_scene_scene_tropes_path(universe_slug: universe.slug, story_id: story, scene_id: scene)
    assert_response :not_found

    sign_out
    get universe_story_scene_scene_tropes_path(universe_slug: universe.slug, story_id: story, scene_id: scene)
    assert_response :not_found
  end

  test "an assignment cannot be managed through another scene, story, or universe" do
    assignment = scene_tropes(:scene_one_red_herring)

    patch universe_story_scene_scene_trope_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: scenes(:scene_two), id: assignment), params: { scene_trope: { context_note: "stolen" } }, as: :json
    assert_response :not_found

    assert_no_difference("SceneTrope.count") do
      delete universe_story_scene_scene_trope_path(universe_slug: @universe.slug, story_id: @story,
        scene_id: scenes(:scene_two), id: assignment), as: :json
    end
    assert_response :not_found

    assert_equal "This scene plants the misleading clue.", assignment.reload.context_note
  end

  test "a remembered assignment applies through the live path" do
    @universe.update!(collaboration_mode: "wikipedia")

    post @path, params: { scene_trope: { trope_slug: "chekhovs-gun", context_note: "Drafted payoff note." } },
      as: :json
    assert_response :accepted

    change = DraftChange.order(:id).last
    assert_equal "SceneTrope", change.record_type
    assert_equal @scene.id, change.payload["scene_id"]

    DraftApplier.new(change.draft).apply

    assignment = @scene.scene_tropes.find_by!(trope_slug: "chekhovs-gun")
    assert_equal "Drafted payoff note.", assignment.context_note
  end

  test "a remembered assignment is named on the draft page" do
    @universe.update!(collaboration_mode: "wikipedia")

    assert_difference("DraftChange.count") do
      post @path, params: { scene_trope: { trope_slug: "chekhovs-gun", context_note: "The detail pays off later." } },
        as: :json
    end
    assert_response :accepted

    get universe_draft_url(universe_slug: @universe.slug, id: Draft.order(:id).last)

    assert_response :success
    # A remembered create has no record yet, so the row names the kind it would
    # create; its values name the catalogue reference rather than the stable slug.
    assert_select ".draft-change .entity-title", text: "New trope annotation"
    assert_select ".draft-change .entity-description", text: /Trope: Chekhov’s Gun/
    assert_select ".draft-change .small", text: "trope annotation"
    assert_includes response.body, "The detail pays off later."
  end
end
