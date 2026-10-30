require "test_helper"

# A Character description is Markdown, and its `[[kind:slug]]` references are
# the source's links. Rendering is a read, so the test is about what a reader
# sees: headings and emphasis, a link only to a record that exists in the same
# Universe, and an unknown or wrong-kind reference left as the author wrote it.
class CharacterDescriptionTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @universe = universes(:universe_one)
    @other = universes(:universe_two)
  end

  test "renders Markdown headings and bold text" do
    html = render("## Wants\n\nFind **the key**.")

    document = Nokogiri::HTML.fragment(html)
    assert_equal "Wants", document.at_css("h2").text
    assert_equal "the key", document.at_css("strong").text
  end

  test "a typed reference to a Character becomes a link named by that record" do
    character = @universe.characters.create!(name: "Ada")

    html = render("Meet [[character:ada]].")

    link = Nokogiri::HTML.fragment(html).at_css("a")
    assert_equal "Ada", link.text
    assert_equal universe_character_path(universe_slug: @universe.slug, id: character), link["href"]
  end

  test "a typed reference to a Location becomes a link to the Location" do
    location = @universe.locations.create!(name: "The Keep")

    html = render("Go to [[location:the-keep]].")

    link = Nokogiri::HTML.fragment(html).at_css("a")
    assert_equal "The Keep", link.text
    assert_equal universe_location_path(universe_slug: @universe.slug, id: location), link["href"]
  end

  test "a bare reference still resolves across the Universe kinds" do
    character = @universe.characters.create!(name: "Ada")

    html = render("Meet [[ada]].")

    link = Nokogiri::HTML.fragment(html).at_css("a")
    assert_equal "Ada", link.text
    assert_equal universe_character_path(universe_slug: @universe.slug, id: character), link["href"]
  end

  test "a canon rule reference links even though the ledger id is uppercase" do
    rule = canon_rules(:canon_rule_one)

    html = render("See [[rule:K1]].")

    link = Nokogiri::HTML.fragment(html).at_css("a")
    assert_equal rule.display_string, link.text
    assert_equal universe_canon_rule_path(universe_slug: @universe.slug, id: rule), link["href"]
  end

  test "a reference to another Universe's record stays literal" do
    @other.characters.create!(name: "Elsewhere")

    html = render("Meet [[character:elsewhere]].")

    assert_nil Nokogiri::HTML.fragment(html).at_css("a")
    assert_includes html, "[[character:elsewhere]]"
  end

  test "a typed reference to the wrong kind stays literal" do
    @universe.locations.create!(name: "The Keep")

    html = render("Meet [[character:the-keep]].")

    assert_nil Nokogiri::HTML.fragment(html).at_css("a")
    assert_includes html, "[[character:the-keep]]"
  end

  test "a reference inside code is an example, not a link" do
    @universe.characters.create!(name: "Ada")

    html = render("Write `[[character:ada]]` to link her.")

    assert_nil Nokogiri::HTML.fragment(html).at_css("a")
    assert_includes html, "[[character:ada]]"
  end

  test "raw HTML in the stored body is stripped" do
    html = render("<script>alert('x')</script>")

    assert_not_includes html, "<script>"
  end

  test "a blank description renders nothing" do
    assert_equal "", render(nil)
    assert_equal "", render("")
  end

  private
    def render(text)
      CharacterDescription.new(@universe, text).to_html
    end
end
