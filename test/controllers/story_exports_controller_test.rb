require "test_helper"

class StoryExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  def export_url(story: @story, universe: @universe)
    universe_story_export_url(universe_slug: universe.slug, story_id: story)
  end

  def export_path(story: @story, universe: @universe)
    universe_story_export_path(universe_slug: universe.slug, story_id: story)
  end

  def manuscript_url(scope: nil, story: @story, universe: @universe)
    url = universe_story_export_manuscript_url(universe_slug: universe.slug, story_id: story)
    scope ? "#{url}?scope=#{scope}" : url
  end

  test "the export page offers the printable format and its three scopes" do
    get export_url

    assert_response :success
    assert_select "h1", text: "Export"
    assert_select ".page-eyebrow", text: "Story: Story One"
    assert_select "form[action=?][method=get]", universe_story_export_manuscript_path(story_id: @story) do
      assert_select "input[type=radio][name=scope]", count: 3
      Manuscript::SCOPES.each do |scope|
        assert_select "input[type=radio][name=scope][value=?]", scope
      end
      assert_select "input[type=submit][value=?]", "Open printable page"
    end
    assert_select "a[href=?]", universe_story_path(id: @story), text: "Back to story"
    assert_select "p", text: /Only saved records are exported/
  end

  test "the export page is on the story sidebar" do
    get universe_path(universe_slug: @universe.slug)
    assert_select "a[href=?]", export_path, count: 0

    get universe_story_url(universe_slug: @universe.slug, id: @story)
    assert_select "a[href=?]", export_path, text: /Export/
  end

  test "the prose manuscript prints sections, scene titles, and the written elements" do
    get manuscript_url

    assert_response :success
    assert_select "body.manuscript-body"
    assert_select "nav", count: 0
    assert_select "form", count: 0

    assert_select "h1.manuscript-story-title", text: "Story One"
    assert_select ".manuscript-section-title", text: "Section one"
    assert_select ".manuscript-section-title", text: "Section two"
    assert_select ".manuscript-section-title", text: "Ungrouped"

    assert_select ".manuscript-scene-title", text: "Scene one"
    assert_select ".manuscript-scene-title", text: "Scene two"

    # Narration prints its body. A Dialogue with line-level turns prints the
    # turns and their speakers, not the block body those lines repeat.
    assert_select "p.manuscript-prose", text: /Jonas wedges the box into the hollow of the oak/
    assert_select ".manuscript-speaker", text: /Character three/
    assert_select ".manuscript-line", text: "Count with me."
    assert_select ".manuscript-line", text: "One, two, three. Again, and slower this time."
    assert_select ".manuscript-parenthetical", text: "(grinning)"
    assert_select ".manuscript-scene", text: /Count with me\. One, two, three/, count: 0

    # No notes and no appendices in the plain-prose document.
    assert_select ".manuscript-notes", count: 0
    assert_select "h2", text: "Universe bible", count: 0
  end

  test "the printable prose marks a registered name and keeps a suggestion distinct" do
    character = @universe.characters.create!(name: "Mira")
    scene = @story.scenes.create!(name: "The gate", position: 10)
    scene.scene_elements.create!(name: "At the gate", kind: "narration",
      body: "Mira waits by the gate.")

    get manuscript_url

    assert_response :success
    assert_select ".manuscript-prose a.mention", text: /Mira/ do |links|
      assert_equal universe_character_path(universe_slug: @universe.slug, id: character), links.first["href"]
    end
    assert_select ".manuscript-prose a.mention--suggested", text: /Mira/
  end

  test "scene elements print in their own position order" do
    scene = @story.scenes.create!(name: "Ordered scene", position: 10)
    scene.scene_elements.create!(name: "Later block", kind: "narration", body: "Later prose", position: 1)
    scene.scene_elements.create!(name: "Earlier block", kind: "narration", body: "Earlier prose", position: 0)

    get manuscript_url

    assert_response :success
    assert_operator response.body.index("Earlier prose"), :<, response.body.index("Later prose")
  end

  test "the front-matter scope adds the scene notes" do
    scenes(:scene_one).update!(pov_character: characters(:character_one))

    get manuscript_url(scope: "front_matter")

    assert_response :success
    assert_select "dt", text: "Point of view"
    assert_select "dd", text: "Character one"
    assert_select "dt", text: "In-world time"
    assert_select "dd", text: "2026-09-11 09:00"

    assert_select "dt", text: "Characters"
    assert_select ".manuscript-note-list", text: /Character one\s+— setting/
    assert_select "dt", text: "Items"
    assert_select ".manuscript-note-list", text: /Item one\s+— carries/
    assert_select "dt", text: "Locations"
    assert_select ".manuscript-note-list", text: /Location one\s+— setting/
    assert_select "dt", text: "Events depicted"
    assert_select ".manuscript-note-list", text: /The beginning - 2026-09-11 09:00/

    assert_select "h2", text: "Universe bible", count: 0
  end

  test "the bible scope appends the universe records" do
    get manuscript_url(scope: "bible")

    assert_response :success
    assert_select "h2", text: "Universe bible"
    assert_select "h3", text: "Characters"
    assert_select "h3", text: "Locations"
    assert_select "h3", text: "Items"
    assert_select "h3", text: "Events"
    assert_select ".manuscript-appendix-name", text: "Character three"
    assert_select ".manuscript-appendix-name", text: "The beginning - 2026-09-11 09:00"
    assert_select ".manuscript-appendix", text: /Character other universe/, count: 0

    # The larger scope still carries the notes it contains.
    assert_select ".manuscript-notes", text: /In-world time/
  end

  test "an unknown scope is the plain prose export" do
    get manuscript_url(scope: "screenplay")

    assert_response :success
    assert_select ".manuscript-notes", count: 0
    assert_select "h2", text: "Universe bible", count: 0
    assert_select "p.manuscript-prose", text: /Jonas wedges the box/
  end

  test "a story with no scenes says there is nothing to export" do
    empty_story = @universe.stories.create!(name: "Empty story")

    get manuscript_url(story: empty_story)

    assert_response :success
    assert_select ".manuscript-empty", text: "This story has no scenes yet, so there is nothing to export."
  end

  test "a public universe is exportable by a guest" do
    sign_out

    get export_url
    assert_response :success
    assert_select "h1", text: "Export"

    get manuscript_url
    assert_response :success
    assert_select "h1.manuscript-story-title", text: "Story One"
  end

  test "a private universe refuses a guest and a member may read" do
    private_universe = Universe.create!(owner: users(:user_two), name: "Private export",
      slug: "private-export", private: true)
    private_story = private_universe.stories.create!(name: "Private story")

    sign_out
    get export_url(story: private_story, universe: private_universe)
    assert_response :not_found

    sign_in_as(users(:user_one))
    get export_url(story: private_story, universe: private_universe)
    assert_response :not_found

    UniverseMembership.create!(universe: private_universe, user: users(:user_one), access_level: :read)
    get export_url(story: private_story, universe: private_universe)
    assert_response :success

    get manuscript_url(story: private_story, universe: private_universe)
    assert_response :success
  end

  test "another story is a 404 on both export pages" do
    get export_url(story: stories(:story_two))
    assert_response :not_found

    get manuscript_url(story: stories(:story_two))
    assert_response :not_found
  end

  test "the export pages are Spanish when the reader's language is Spanish" do
    patch settings_url, params: { locale: "es" }

    get export_url
    assert_response :success
    assert_select "h1", text: "Exportar"
    assert_select "input[type=submit][value=?]", "Abrir la página imprimible"
    assert_select "input[type=radio][value=front_matter]"

    get manuscript_url
    assert_response :success
    assert_select "h1.manuscript-story-title", text: "Story One"
    assert_select ".manuscript-print-hint", text: /comando de impresión/
  end
end
