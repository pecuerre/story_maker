require "test_helper"

# "Who is here" is the Location details page's read of Scene presence in the
# current Story. Like "Appears in scenes" it is read-only navigation, so it
# renders for every access level and never crosses into another Story.
class LocationPresenceSectionTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @location = locations(:location_one)
    sign_in_as(users(:user_one))
  end

  # A Story is only current once the request has selected one, exactly as the
  # sidebar requires.
  def select_story(story)
    get universe_story_path(universe_slug: @universe.slug, id: story)
    assert_response :success
  end

  def presence_section(title = "Who is here in #{@story.name}")
    Nokogiri::HTML(response.body).css("section.detail-section")
      .find { |section| section.at_css("h2")&.text&.squish == title }
  end

  def scene_links(section)
    section.css(".entity-title a").map { |link| link["href"] }
  end

  test "one row per scene names the individuals, their reasons, and their factions" do
    select_story(@story)

    get universe_location_path(universe_slug: @universe.slug, id: @location)

    assert_response :success
    section = presence_section
    assert section, "the Who is here section is on the page"

    # Narrative order, and only the scenes of the current Story that happen here.
    assert_equal [ universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_one)),
      universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_three)) ],
      scene_links(section)
    assert_not_includes scene_links(section),
      universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_two))

    text = section.text.squish
    # The place's own role in each Scene, which is not a person's reason.
    assert_includes text, "Location role: setting"
    assert_includes text, "Location role: arrives at"
    # Factions are the participants' memberships, so the faction is named because
    # one of its members is present.
    assert_includes text, "Factions present:"
    assert_includes text, "Faction one"
    # The individual's stored free-text role is the reason; speaking is derived
    # and says so. A linked participant with no role says that too.
    assert_includes text, "Character one — setting and speaks in this scene"
    assert_includes text, "Character two — speaks in this scene"
    assert_includes text, "Character three — speaks in this scene"
    # Scene three has the Location but no participants, and says so rather than
    # hiding the row: the Scene still happens here.
    assert_includes text, "No faction recorded."
    assert_includes text, "No individual recorded."
  end

  test "a scene at the place with nobody in it is still a row" do
    empty_hall = @universe.locations.create!(name: "Empty hall")
    scenes(:scene_three).scene_locations.create!(location: empty_hall)
    select_story(@story)

    get universe_location_path(universe_slug: @universe.slug, id: empty_hall)

    assert_response :success
    section = presence_section
    assert_equal 1, scene_links(section).size
    assert_includes section.text.squish, "No faction recorded."
    assert_includes section.text.squish, "No individual recorded."
    assert section.css(".badge").any? { |badge| badge["aria-label"] == "1 scene" }
  end

  test "without a current story the section asks for one instead of guessing" do
    get universe_location_path(universe_slug: @universe.slug, id: @location)

    assert_response :success
    section = presence_section("Who is here")
    assert section
    assert_includes section.text.squish, "Select a story to see who is here"
    assert_select ".empty-state a[href=?]", universe_stories_path(universe_slug: @universe.slug), text: "All stories"
  end

  test "a location with no scene in the selected story says so by name" do
    select_story(stories(:story_alt))

    get universe_location_path(universe_slug: @universe.slug, id: @location)

    assert_response :success
    section = presence_section("Who is here in Spin-off")
    assert section
    assert_includes section.text.squish, "No one is recorded here in Spin-off"
  end

  test "a guest sees the same read-only presence" do
    select_story(@story)
    sign_out

    get universe_location_path(universe_slug: @universe.slug, id: @location)

    assert_response :success
    section = presence_section
    assert_equal 2, scene_links(section).size
    assert_empty section.css(".dropdown, button")
  end
end
