require "test_helper"

class AppearancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = @universe.stories.create!(name: "Grid story")
    @mira = @universe.characters.create!(name: "Mira")
    @nico = @universe.characters.create!(name: "Nico")
    @pia = @universe.characters.create!(name: "Pia")
    @first = @story.scenes.create!(name: "First scene", position: 0)
    @second = @story.scenes.create!(name: "Second scene", position: 1)
    @act = @story.sections.create!(name: "Act One")
    @sequence = @story.sections.create!(name: "The Long Night", parent: @act)
    @first.update!(section: @sequence)
    @first.scene_characters.create!(character: @mira)
    @first.scene_characters.create!(character: @pia)
    @first.scene_elements.create!(name: "Mira block", kind: "narration", body: "Mira waits.")
    @second.scene_elements.create!(name: "Nico block", kind: "narration", body: "Nico watches.")
    sign_in_as(users(:user_one))
  end

  def appearances_path(story: @story)
    universe_story_appearances_path(universe_slug: @universe.slug, story_id: story)
  end

  test "the page renders the story grid with both layers and their legend" do
    get appearances_path

    assert_response :success
    assert_select "h1", text: "Appearance grid"
    # The grid is its own Story analytics destination, not a tab of the Scene
    # workspace.
    assert_select "nav.content-tabs", 0
    assert_select "aside.workspace-sidebar section[aria-labelledby='story-analytics-title'] a.sidebar-link.active[aria-current=page][href=?]",
      appearances_path do
      assert_select ".sidebar-link-label", text: "Appearances"
    end
    assert_select "a[href=?]", universe_story_path(universe_slug: @universe.slug, id: @story), text: "Story overview"

    assert_select ".appearance-grid thead th", text: "Character"
    assert_select ".appearance-grid thead a.appearance-grid-scene-link", count: 2
    assert_select ".appearance-grid tbody th a.appearance-grid-character-link", text: "Mira"
    assert_select ".appearance-grid tbody th a.appearance-grid-character-link", text: "Nico"

    assert_select ".appearance-grid td.appearance-grid-cell--both .appearance-mark--present"
    assert_select ".appearance-grid td.appearance-grid-cell--both .appearance-mark--mention"
    assert_select ".appearance-grid td.appearance-grid-cell--mention .appearance-mark--mention"
    assert_select ".appearance-grid td.appearance-grid-cell--present .appearance-mark--present"
    assert_select ".appearance-grid .visually-hidden", text: "Appears and is mentioned"
    assert_select ".appearance-grid .visually-hidden", text: "Mentioned"

    assert_select ".appearance-grid-legend", text: /A mention is not an appearance/
    assert_select ".appearance-grid-legend", text: /Recorded appearance/
  end

  test "a scene column is its position, with the section and scene in its popover" do
    get appearances_path

    assert_response :success
    links = css_select(".appearance-grid thead a.appearance-grid-scene-link")
    assert_equal [ "1", "2" ],
      links.map { |link| link.at_css(".appearance-grid-position").text.strip }
    assert_equal [ "Scene 1: First scene", "Scene 2: Second scene" ],
      links.map { |link| link["aria-label"] }

    first, second = links
    assert_equal "popover", first["data-controller"]
    # The popover is body only: the Section path one level per line, then the
    # Scene. There is no title, so the section is not repeated.
    assert_nil first["data-popover-title-value"]
    assert_equal "Act One\nThe Long Night\nScene: (1) First scene",
      first["data-popover-content-value"]
    assert_equal "bottom", first["data-popover-placement-value"]
    assert_equal "hover focus", first["data-bs-trigger"]
    assert_includes first["data-bs-custom-class"], "appearance-grid-popover"
    # A Scene in no Section says so instead of an empty first line.
    assert_equal "Ungrouped\nScene: (2) Second scene", second["data-popover-content-value"]

    # The name is still rendered for paper, hidden on screen.
    assert_select ".appearance-grid thead .appearance-grid-scene-print", text: "First scene", count: 1
  end

  test "the grid is read-only" do
    get appearances_path

    assert_response :success
    assert_select ".appearance-grid form", count: 0
    assert_select ".appearance-grid button", count: 0
    assert_select ".appearance-grid input", count: 0
  end

  test "a guest can read the grid of a public universe" do
    sign_out

    get appearances_path

    assert_response :success
    assert_select ".appearance-grid", count: 1
  end

  test "a story with no scenes gets the empty state rather than an empty table" do
    empty = @universe.stories.create!(name: "No scenes")
    get appearances_path(story: empty)

    assert_response :success
    assert_select ".empty-title", text: "No scenes yet"
    assert_select ".appearance-grid", count: 0
  end

  test "a story with scenes but no presence or mentions gets the no-character empty state" do
    bare = @universe.stories.create!(name: "Bare story")
    bare.scenes.create!(name: "Empty scene", position: 0)
    get appearances_path(story: bare)

    assert_response :success
    assert_select ".empty-title", text: "No characters appear or are mentioned in Bare story yet"
    assert_select ".appearance-grid", count: 0
  end

  test "the story overview offers the grid" do
    get universe_story_path(universe_slug: @universe.slug, id: @story)

    assert_response :success
    assert_select "a[href=?]", appearances_path, text: "Open appearance grid"
  end

  test "another universe's story is a 404" do
    get universe_story_appearances_path(universe_slug: universes(:universe_two).slug, story_id: @story)

    assert_response :not_found
  end
end
