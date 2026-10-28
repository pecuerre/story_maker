require "test_helper"

# The Character details page states prose mentions beside recorded appearances.
# The section is a suggestion list, not a second appearances list: a name written
# in a Scene that already records the Character is left to the appearances
# section above it.
class CharacterMentionsTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @character = @universe.characters.create!(name: "Mira", aliases: "The Fox")
    sign_in_as(users(:user_one))
  end

  def select_story(story)
    get universe_story_path(universe_slug: @universe.slug, id: story)
    assert_response :success
  end

  def section_starting_with(title)
    css_select("section.detail-section").find do |section|
      section.at_css("h2")&.text&.squish&.start_with?(title)
    end
  end

  def add_element(scene, body, name: "Mira block")
    scene.scene_elements.create!(name: name, kind: "narration", body: body)
  end

  test "only mentions in scenes without recorded presence are suggested" do
    suggested = @story.scenes.create!(name: "The unrecorded gate", position: 3)
    recorded = @story.scenes.create!(name: "The recorded gate", position: 4)
    add_element(suggested, "Mira waits at the gate.", name: "At the gate")
    add_element(recorded, "Mira waits inside.", name: "Inside")
    recorded.scene_characters.create!(character: @character)
    select_story(@story)

    get universe_character_path(universe_slug: @universe.slug, id: @character)

    assert_response :success
    mentions = section_starting_with("Mentioned in prose")
    refute_nil mentions
    assert_equal [ universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: suggested) ],
      mentions.css("a.details-link").map { |link| link["href"] }
    assert_select "section.detail-section .badge", text: "Not recorded as present"
    assert_includes response.body, "Mentioned in: At the gate"
  end

  test "an alias is reported as the spelling the author wrote" do
    scene = @story.scenes.create!(name: "The fox's road", position: 3)
    add_element(scene, "The Fox walks the road.")
    select_story(@story)

    get universe_character_path(universe_slug: @universe.slug, id: @character)

    assert_response :success
    assert_includes response.body, "Written as The Fox"
    assert_select "section.detail-section a.details-link[href=?]",
      universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: scene)
  end

  test "without a current story the section asks for one" do
    sign_out
    sign_in_as(users(:user_one))

    get universe_character_path(universe_slug: @universe.slug, id: @character)

    assert_response :success
    assert_select "section.detail-section h2", text: "Mentioned in prose"
    assert_select ".empty-title", text: "Select a story to see prose mentions"
    assert_select ".empty-state a[href=?]", universe_stories_path(universe_slug: @universe.slug), text: "All stories"
  end
end
