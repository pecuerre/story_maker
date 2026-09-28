require "test_helper"

class CharacterTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @character_tag = character_tags(:character_tag_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get universe_character_tags_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Character Tags"
    assert_includes response.body, @character_tag.name
  end

  test "should create character tag as json" do
    assert_difference("CharacterTag.count") do
      post universe_character_tags_url(universe_slug: @universe.slug),
        params: { character_tag: { name: "New character tag", description: "A description" } },
        as: :json
    end

    assert_response :created
    assert_equal "New character tag", response.parsed_body["name"]
    assert_equal "A description", CharacterTag.order(:id).last.description
  end

  test "should update character tag as json" do
    patch universe_character_tag_url(universe_slug: @universe.slug, id: @character_tag),
      params: { character_tag: { name: "Renamed", description: "Updated" } },
      as: :json

    assert_response :success
    assert_equal [ "Renamed", "Updated" ], @character_tag.reload.values_at(:name, :description)
  end

  test "a rejected taxonomy mutation answers 422 with the error hash the editor renders" do
    patch universe_character_tag_url(universe_slug: @universe.slug, id: @character_tag),
      params: { character_tag: { name: "" } },
      as: :json

    assert_response :unprocessable_content
    assert_equal [ "can't be blank" ], response.parsed_body["name"]
    assert_equal "Character tag one", @character_tag.reload.name
  end

  test "an association rejection is keyed on the association so the editor can find the field" do
    foreign_tag = character_tags(:character_tag_three)
    child = CharacterTag.create!(universe: @universe, name: "Nested tag", parent: @character_tag)

    patch universe_character_tag_url(universe_slug: @universe.slug, id: child),
      params: { character_tag: { name: child.name, parent_id: foreign_tag.id } },
      as: :json

    assert_response :unprocessable_content
    assert_equal [ "must belong to the same universe" ], response.parsed_body["parent"]
  end

  test "creates a grouping tag that is not taggable but is pinned to the menu" do
    assert_difference("CharacterTag.count") do
      post universe_character_tags_url(universe_slug: @universe.slug),
        params: { character_tag: { name: "Factions", taggable: false, show_in_menu: true } },
        as: :json
    end

    assert_response :created
    created = CharacterTag.find_by(name: "Factions")
    assert_equal false, response.parsed_body["taggable"]
    assert_equal true, response.parsed_body["show_in_menu"]
    assert_not created.taggable
    assert created.show_in_menu
  end

  test "updates taggable and show_in_menu" do
    patch universe_character_tag_url(universe_slug: @universe.slug, id: @character_tag),
      params: { character_tag: { name: @character_tag.name, taggable: false, show_in_menu: true } },
      as: :json

    assert_response :success
    assert_equal [ false, true ], @character_tag.reload.values_at(:taggable, :show_in_menu)
    assert_equal [ false, true ], response.parsed_body.values_at("taggable", "show_in_menu")
  end

  test "show includes records from child tags by default" do
    get universe_character_tag_url(universe_slug: @universe.slug, id: @character_tag)

    assert_response :success
    assert_includes response.body, "Character one"
    assert_includes response.body, "Character three"
    assert_includes response.body, "Include records from child tags"
  end

  test "a non-taggable grouping tag lists records under each direct child without a descendant toggle" do
    grouping = CharacterTag.create!(universe: @universe, name: "Factions", taggable: false, show_in_menu: true)
    sic_mundus = CharacterTag.create!(universe: @universe, name: "Sic Mundus", parent: grouping)
    erit_lux = CharacterTag.create!(universe: @universe, name: "Erit Lux", parent: grouping)
    sic_character = Character.create!(universe: @universe, name: "Sic character", character_tags: [ sic_mundus ])
    erit_character = Character.create!(universe: @universe, name: "Erit character", character_tags: [ erit_lux ])

    get universe_character_tag_url(universe_slug: @universe.slug, id: grouping)

    assert_response :success
    assert_includes response.body, sic_character.name
    assert_includes response.body, erit_character.name
    assert_not_includes response.body, "Include records from child tags"

    document = Nokogiri::HTML(response.body)
    sic_section = document.css(".detail-section").find { |section| section.at_css("h2")&.text == sic_mundus.name }
    erit_section = document.css(".detail-section").find { |section| section.at_css("h2")&.text == erit_lux.name }
    assert_includes sic_section.text, sic_character.name
    assert_not_includes sic_section.text, erit_character.name
    assert_includes erit_section.text, erit_character.name
    assert_not_includes erit_section.text, sic_character.name
  end

  test "a workspace tag link keeps the content tabs while a taxonomy details link does not" do
    menu_tag = CharacterTag.create!(universe: @universe, name: "Family Nielsen", taggable: true, show_in_menu: true)
    workspace_path = universe_character_tag_url(universe_slug: @universe.slug, id: menu_tag, from: "workspace")

    get workspace_path

    assert_response :success
    assert_select "nav.content-tabs a.active[aria-current=page][href=?]",
      universe_character_tag_path(universe_slug: @universe.slug, id: menu_tag, from: "workspace"), text: "Family Nielsen"
    assert_select "nav.content-tabs a[href=?]", universe_characters_path(universe_slug: @universe.slug), text: "Characters"

    taxonomy_details_path = universe_character_tag_path(universe_slug: @universe.slug, id: menu_tag)
    get universe_tags_url(universe_slug: @universe.slug, taxonomy: "character")

    assert_response :success
    assert_select "a[href=?]", taxonomy_details_path

    get taxonomy_details_path

    assert_response :success
    assert_select "nav.content-tabs", count: 0
  end

  test "the workspace tab strip sits above the tag's identity card" do
    menu_tag = CharacterTag.create!(universe: @universe, name: "Family Nielsen", taggable: true, show_in_menu: true)

    get universe_character_tag_url(universe_slug: @universe.slug, id: menu_tag, from: "workspace")

    assert_response :success
    assert_equal [ :header, :tabs, :card ], main_blocks.first(3)
  end

  test "a taxonomy details link has no tab strip, so the identity card follows the page header" do
    get universe_character_tag_url(universe_slug: @universe.slug, id: character_tags(:character_tag_one))

    assert_response :success
    assert_equal [ :header, :card ], main_blocks.first(2)
  end

  test "show with include_descendants=0 excludes records from child tags" do
    get universe_character_tag_url(universe_slug: @universe.slug, id: @character_tag, include_descendants: "0")

    assert_response :success
    assert_includes response.body, "Character one"
    assert_not_includes response.body, "Character three"
  end

  test "show with include_descendants=1 includes records from child tags" do
    get universe_character_tag_url(universe_slug: @universe.slug, id: @character_tag, include_descendants: "1")

    assert_response :success
    assert_includes response.body, "Character one"
    assert_includes response.body, "Character three"
  end

  private

    # The tag page's own blocks in the order a reader meets them. The tab strip
    # is page navigation, so it sits with the header above the identity card
    # rather than below it.
    def main_blocks
      Nokogiri::HTML(response.body).css("main .page-shell > *").filter_map do |node|
        classes = node["class"].to_s
        next :header if classes.include?("page-header")
        next :tabs if classes.include?("content-tabs")
        next :card if classes.include?("surface-card")
      end
    end
end
