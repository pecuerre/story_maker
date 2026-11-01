require "test_helper"

# A record's description is Markdown, and its `[[kind:slug]]` references are the
# source's links. Rendering is a read, so the test is about what a reader sees:
# headings and emphasis, a link only to a record that exists in the same
# Universe, and an unknown or wrong-kind reference left as the author wrote it.
class MarkdownDescriptionTest < ActiveSupport::TestCase
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

  test "a typed reference to a Faction becomes a link to the Faction" do
    faction = @universe.factions.create!(name: "The Wardens")

    html = render("Join [[faction:the-wardens]].")

    link = Nokogiri::HTML.fragment(html).at_css("a")
    assert_equal "The Wardens", link.text
    assert_equal universe_faction_path(universe_slug: @universe.slug, id: faction), link["href"]
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
    assert_equal "K1", link.text
    assert_equal universe_canon_rule_path(universe_slug: @universe.slug, id: rule), link["href"]
  end

  test "a canon reference keeps the ledger id as the link text" do
    rule = canon_rules(:canon_rule_one)

    html = render("See [[canon:K1]].")

    link = Nokogiri::HTML.fragment(html).at_css("a")
    assert_equal "K1", link.text
    assert_equal universe_canon_rule_path(universe_slug: @universe.slug, id: rule), link["href"]
  end

  test "as plain text a canon reference keeps the ledger id" do
    canon_rules(:canon_rule_one)

    text = MarkdownDescription.new(@universe, "See [[canon:K1]].")

    assert_equal "See K1.", text.as_plain_text
  end

  test "as plain text a canon reference in a summary keeps the ledger id" do
    canon_rules(:canon_rule_one)

    html = MarkdownDescription.new(@universe, "See [[canon:K1]].").to_inline_html

    assert_equal "K1", Nokogiri::HTML.fragment(html).at_css("a").text
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

  test "the summary links a reference without interpreting Markdown" do
    character = @universe.characters.create!(name: "Ada")

    html = MarkdownDescription.new(@universe, "Meet [[character:ada]] in **the hall**.").to_inline_html

    document = Nokogiri::HTML.fragment(html)
    link = document.at_css("a")
    assert_equal "Ada", link.text
    assert_equal universe_character_path(universe_slug: @universe.slug, id: character), link["href"]
    assert_nil document.at_css("strong"), "a summary is plain text, so ** is not emphasis"
  end

  test "the summary escapes its prose" do
    html = MarkdownDescription.new(@universe, "<script>alert('x')</script>").to_inline_html

    assert_not_includes html, "<script>"
    assert_includes html, "&lt;script&gt;"
  end

  test "the summary leaves an unresolved reference as written" do
    html = MarkdownDescription.new(@universe, "Meet [[character:nobody]].").to_inline_html

    assert_nil Nokogiri::HTML.fragment(html).at_css("a")
    assert_includes html, "[[character:nobody]]"
  end

  test "as plain text a reference becomes the name it names, with no link" do
    @universe.characters.create!(name: "Ada")
    @universe.factions.create!(name: "The Wardens")

    text = MarkdownDescription.new(@universe, "Meet [[character:ada]] of [[the-wardens]].")

    assert_equal "Meet Ada of The Wardens.", text.as_plain_text
  end

  test "as plain text an unresolved reference is left as written" do
    text = MarkdownDescription.new(@universe, "Meet [[character:nobody]].")

    assert_equal "Meet [[character:nobody]].", text.as_plain_text
  end

  private
    def render(text)
      MarkdownDescription.new(@universe, text).to_html
    end
end
