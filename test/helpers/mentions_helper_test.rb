require "test_helper"

# Highlighting prose is the first surface of the mention index, so it has to
# escape the author's text, link only registered names, and keep a suggestion
# visually and accessibly separate from a recorded appearance.
class MentionsHelperTest < ActionView::TestCase
  include MentionsHelper

  setup do
    @universe = universes(:universe_one)
    @character = @universe.characters.create!(name: "Mira")
    @index = MentionIndex.new([ @character ])
    Current.universe = @universe
  end

  teardown do
    Current.universe = nil
  end

  def fragment(html)
    Nokogiri::HTML.fragment(html)
  end

  test "a recognized name becomes a link and the rest of the body is preserved" do
    html = highlighted_mentions("Before Mira after", index: @index,
      present_character_ids: [ @character.id ])
    link = fragment(html).at_css("a.mention")

    assert_equal "Before ", fragment(html).children.first.text
    assert_equal " after", fragment(html).children.last.text
    assert_equal "Mira", link.text
    assert_equal universe_character_path(universe_slug: @universe.slug, id: @character), link["href"]
    assert_not_includes html, "mention--suggested"
    assert_not_includes html, "visually-hidden"
  end

  test "a mention in a scene without recorded presence is a suggestion" do
    html = highlighted_mentions("Mira waits", index: @index, present_character_ids: [])
    link = fragment(html).at_css("a.mention--suggested")

    assert_equal "Mira #{I18n.t("shared.mention.suggested_note")}", link.text
    assert_equal I18n.t("shared.mention.suggested_title"), link["title"]
    assert_equal I18n.t("shared.mention.suggested_note"),
      link.at_css("span.visually-hidden").text.strip
  end

  test "author text is escaped even when no name matches" do
    html = highlighted_mentions("<script>alert('x')</script>", index: @index,
      present_character_ids: [])

    assert_not_includes html, "<script>"
    assert_includes html, "&lt;script&gt;"
  end

  test "author text around a match is escaped and only the name is markup" do
    html = highlighted_mentions("<b>Mira</b>", index: @index, present_character_ids: [])

    assert_not_includes html, "<b>"
    assert_includes html, "&lt;b&gt;"
    assert_includes fragment(html).at_css("a.mention").text, "Mira"
  end

  test "a name inside a larger word is not linked" do
    html = highlighted_mentions("Miranda waits", index: @index, present_character_ids: [])

    assert_nil fragment(html).at_css("a.mention")
    assert_includes html, "Miranda waits"
  end

  test "a blank body renders nothing and an absent index still preserves the text" do
    assert_equal "", highlighted_mentions(nil, index: @index, present_character_ids: [])
    assert_equal "", highlighted_mentions("", index: @index, present_character_ids: [])
    assert_equal "Mira", highlighted_mentions("Mira", index: nil, present_character_ids: [])
  end
end
