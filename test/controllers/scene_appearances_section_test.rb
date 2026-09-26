require "test_helper"

# The "Appears in scenes" section is the reverse of the Scene workspace tabs. It
# is read-only navigation on a record's own details page, so it renders for every
# access level, and every link it produces carries an explicit Story because a
# Scene has no Universe-level URL.
class SceneAppearancesSectionTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  def appearance_links
    css_select(".detail-section a.details-link").map { |link| link["href"] }
  end

  def section_titles
    css_select(".detail-section h2").map { |title| title.text.squish }
  end

  # A Story is only current once the request has actually selected one, exactly as
  # the sidebar requires. Nothing here is remembered implicitly.
  def select_story(story)
    get universe_story_path(universe_slug: @universe.slug, id: story)
    assert_response :success
  end

  test "a character's appearances name both participation sources" do
    select_story(@story)

    get universe_character_path(universe_slug: @universe.slug, id: characters(:character_one))

    assert_response :success
    assert_includes section_titles, "Appears in scenes of #{@story.name}"
    assert_equal [ universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_one)) ],
      appearance_links
    # A stored link and a derived speaker are one row labelled as both, exactly as
    # the Characters tab shows them.
    assert_select ".detail-section .badge", text: "Linked"
    assert_select ".detail-section .badge", text: "Speaks in 1 element"
    assert_includes response.body, "Role: setting"
    assert_includes response.body, "Speaks in Michael teaches the waltz."
  end

  test "an item and a location list their scenes with their roles" do
    select_story(@story)

    get universe_item_path(universe_slug: @universe.slug, id: items(:item_one))
    assert_response :success
    assert_equal [ universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_one)),
      universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_three)) ],
      appearance_links
    assert_includes response.body, "Role: carries"
    assert_includes response.body, "Role: still missing"

    get universe_location_path(universe_slug: @universe.slug, id: locations(:location_one))
    assert_response :success
    assert_equal 2, appearance_links.size
    assert_includes response.body, "Role: setting"
  end

  test "an event lists every scene that depicts it without merging them" do
    # `event_one` is referenced by `scene_one` only in the fixtures; a second
    # reference is created here because "several scenes may depict one event" is
    # the property under test.
    later = @story.scenes.create!(name: "The same fact, again", position: 3, event: events(:event_one))
    select_story(@story)

    get universe_event_path(universe_slug: @universe.slug, id: events(:event_one))

    assert_response :success
    # Both scenes are listed, in narrative order, and neither is deduplicated.
    assert_equal [ universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_one)),
      universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: later) ],
      appearance_links
    assert_select ".detail-section .badge", text: "Depicted", count: 2
    # An Event reference is not a presence link, so it never shows a role line.
    assert_select ".detail-section .entity-description", count: 0
  end

  test "a record in no scene says so instead of showing an empty box" do
    unused = @universe.items.create!(name: "Never used")
    select_story(@story)

    get universe_item_path(universe_slug: @universe.slug, id: unused)

    assert_response :success
    assert_select ".detail-section h2", text: "Appears in scenes of #{@story.name}"
    assert_select ".empty-title", text: "Not in any scene of #{@story.name} yet"
    assert_select ".detail-section a.details-link", count: 0
  end

  test "without a current story the section asks for one and links to the story list" do
    # The session has never selected a story, so there is no scope to list. The
    # section must not fall back to the universe's first story.
    get universe_item_path(universe_slug: @universe.slug, id: items(:item_one))

    assert_response :success
    assert_select ".detail-section h2", text: "Appears in scenes"
    assert_select ".empty-title", text: "Select a story to see its scenes"
    assert_select ".detail-section a.details-link", count: 0
    assert_select ".empty-state a[href=?]", universe_stories_path(universe_slug: @universe.slug), text: "All stories"
  end

  test "the appearances belong to the story the request selected" do
    # Selecting the Alt story is what makes it current, so the section follows that
    # choice rather than the story the fixtures happen to link to.
    select_story(stories(:story_alt))

    get universe_character_path(universe_slug: @universe.slug, id: characters(:character_one))

    assert_response :success
    assert_includes section_titles, "Appears in scenes of Spin-off"
    # The Alt story's scene is the one that names the character as a speaker, and
    # it is reached through the Alt story. The stored link in Story one is not
    # shown, because appearances never cross into another story.
    assert_equal [ universe_story_scene_path(universe_slug: @universe.slug, story_id: stories(:story_alt),
      id: scenes(:scene_alt)) ], appearance_links
    assert_select ".detail-section .badge", text: "Linked", count: 0
    assert_select ".detail-section .badge", text: "Speaks in 1 element"
  end

  test "a guest and a read-only member see the same read-only section" do
    select_story(@story)
    sign_out

    get universe_item_path(universe_slug: @universe.slug, id: items(:item_one))

    assert_response :success
    assert_equal 2, appearance_links.size
    assert_select "main form", count: 0
    assert_select ".row-actions", count: 0
  end

  test "a private universe's section is a 404 for a non-member and readable for a member" do
    owner = users(:user_one)
    private_universe = Universe.create!(owner: owner, name: "Private appearances", slug: "private-appearances",
      private: true)
    story = Story.create!(universe: private_universe, name: "Private story")
    scene = story.scenes.create!(name: "Private scene", position: 0)
    item = private_universe.items.create!(name: "Private prop")
    scene.scene_items.create!(item: item, role: "carries")

    sign_out
    get universe_item_path(universe_slug: private_universe.slug, id: item)
    assert_response :not_found

    sign_in_as(users(:user_two))
    get universe_item_path(universe_slug: private_universe.slug, id: item)
    assert_response :not_found

    # A read member reaches the same section, with the same link.
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)
    sign_in_as(users(:user_two))
    get universe_story_path(universe_slug: private_universe.slug, id: story)
    assert_response :success
    get universe_item_path(universe_slug: private_universe.slug, id: item)

    assert_response :success
    assert_includes section_titles, "Appears in scenes of #{story.name}"
    assert_equal [ universe_story_scene_path(universe_slug: private_universe.slug, story_id: story, id: scene) ],
      appearance_links
  end

  test "a record from another universe never lists this story's scenes" do
    other = universes(:universe_two)
    outsider = other.items.create!(name: "Outsider")
    # The Alt story of universe one is not the scope here, and universe two has no
    # remembered story of its own, so the section asks rather than guessing.
    select_story(@story)
    get universe_item_path(universe_slug: other.slug, id: outsider)
    assert_response :success
    assert_select ".empty-title", text: "Select a story to see its scenes"
    assert_select ".detail-section a.details-link", count: 0

    other_story = Story.create!(universe: other, name: "Elsewhere story")
    get universe_story_path(universe_slug: other.slug, id: other_story)
    assert_response :success
    get universe_item_path(universe_slug: other.slug, id: outsider)
    assert_response :success
    assert_select ".empty-title", text: "Not in any scene of #{other_story.name} yet"
    assert_select ".detail-section a.details-link", count: 0
  end
end
