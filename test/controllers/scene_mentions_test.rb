require "test_helper"

# Scene Details marks every registered name in an Element body. The link opens
# the Character, and its style says whether the Scene records that Character as
# present — a mention never changes the Characters tab by itself.
class SceneMentionsTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @character = @universe.characters.create!(name: "Mira", aliases: "The Fox")
    @scene = @story.scenes.create!(name: "The gate", position: 3)
    @element = @scene.scene_elements.create!(name: "At the gate", kind: "narration",
      body: "Mira waits. The Fox watches. Miranda is elsewhere.")
    sign_in_as(users(:user_one))
    get universe_story_path(universe_slug: @universe.slug, id: @story)
  end

  def element_path
    universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: @scene)
  end

  def mentions
    css_select(".scene-elements a.mention")
  end

  test "every registered name and alias is linked once, and a longer word is not" do
    get element_path

    assert_response :success
    assert_equal [ "Mira", "The Fox" ], mentions.map { |link| link.children.first.text }
    assert_equal [ universe_character_path(universe_slug: @universe.slug, id: @character) ] * 2,
      mentions.map { |link| link["href"] }
    assert_select ".scene-elements a.mention", text: "Miranda", count: 0
  end

  test "a mention of a character the scene records as present is not a suggestion" do
    @scene.scene_characters.create!(character: @character)

    get element_path

    assert_response :success
    assert_select ".scene-elements a.mention--suggested", count: 0
    assert_select ".scene-elements a.mention", count: 2
    assert_select ".scene-elements p.form-text", text: /dashed underline/
  end

  test "a mention without recorded presence is a suggestion with an accessible note" do
    get element_path

    assert_response :success
    assert_select ".scene-elements a.mention--suggested", count: 2 do |links|
      links.each do |link|
        assert_equal I18n.t("shared.mention.suggested_title"), link["title"]
        note = link.at_css("span.visually-hidden")
        assert_includes note.text, I18n.t("shared.mention.suggested_note")
      end
    end
  end

  test "a speaker is recorded presence even without a stored link" do
    @element.update!(kind: SceneElement::DIALOGUE, characters: [ @character ])

    get element_path

    assert_response :success
    assert_select ".scene-elements a.mention--suggested", count: 0
  end
end
