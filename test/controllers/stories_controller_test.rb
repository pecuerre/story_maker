require "test_helper"

class StoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
  end

  test "uses an explicit /s path for stories and their sections" do
    story = stories(:story_one)

    assert_equal "/u/#{@universe.slug}/s", universe_stories_path(universe_slug: @universe.slug)
    assert_equal "/u/#{@universe.slug}/s/#{story.id}", universe_story_path(universe_slug: @universe.slug, id: story)
    assert_equal "/u/#{@universe.slug}/s/#{story.id}/sections",
      universe_story_sections_path(universe_slug: @universe.slug, story_id: story)
  end

  test "does not route the universe-level sections URL" do
    get "/u/#{@universe.slug}/sections"

    assert_response :not_found
  end

  test "should get index listing only this universe's stories" do
    get universe_stories_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Story One"
    assert_includes response.body, "Spin-off"
    assert_not_includes response.body, "Story Two"
  end

  test "should get story show with workspace context" do
    story = stories(:story_one)

    get universe_story_url(universe_slug: @universe.slug, id: story)

    assert_response :success
    assert_select ".page-header h1", text: story.name
    assert_select ".page-eyebrow", text: I18n.t("sidebar.story_workspace")
    assert_select "a[href=?]", universe_story_sections_path(universe_slug: @universe.slug, story_id: story),
      text: I18n.t("stories.show.open_sections")
    assert_select "a[href=?]", universe_story_plots_path(universe_slug: @universe.slug, story_id: story),
      text: I18n.t("stories.show.open_plots")
    assert_select "a[href=?]", TropeCatalog.find("red-herring").source_url, text: "Red Herring"
    assert_includes response.body, "The clue is introduced fairly and resolved later."
  end

  test "should get new story" do
    get new_universe_story_url(universe_slug: @universe.slug)

    assert_response :success
  end

  test "new story form does not leak its unsaved object into the universe association" do
    get new_universe_story_url(universe_slug: @universe.slug)

    story = @controller.instance_variable_get(:@story)
    assert_not story.persisted?
    assert_equal @universe, story.universe

    story.universe.stories.load
    assert_not_includes story.universe.stories.target, story
  end

  test "should create story" do
    assert_difference("Story.count") do
      post universe_stories_url(universe_slug: @universe.slug),
        params: { story: { name: "House of the Dragon", description: "A new story" } }
    end

    story = Story.order(:id).last
    assert_redirected_to universe_story_url(universe_slug: @universe.slug, id: story)
    assert_equal @universe, story.universe
    assert_equal "house-of-the-dragon", story.slug
  end

  test "should not create story without a name" do
    assert_no_difference("Story.count") do
      post universe_stories_url(universe_slug: @universe.slug), params: { story: { name: "" } }
    end

    assert_response :unprocessable_content
  end

  test "story editor saves a contextual trope annotation" do
    story = stories(:story_alt)

    assert_difference("StoryTrope.count") do
      patch universe_story_url(universe_slug: @universe.slug, id: story), params: {
        story: {
          story_tropes_attributes: {
            "0" => { trope_slug: "red-herring", selected: "1", context_note: "The false lead is resolved fairly." }
          }
        }
      }
    end

    assert_redirected_to universe_story_url(universe_slug: @universe.slug, id: story)
    assert_equal "The false lead is resolved fairly.", story.story_tropes.find_by!(trope_slug: "red-herring").context_note
  end

  test "story editor refuses a trope outside the curated catalogue" do
    story = stories(:story_alt)

    assert_no_difference("StoryTrope.count") do
      patch universe_story_url(universe_slug: @universe.slug, id: story), params: {
        story: {
          story_tropes_attributes: {
            "0" => { trope_slug: "unknown", selected: "1", context_note: "No such reference." }
          }
        }
      }
    end

    assert_response :unprocessable_content
  end

  test "unchecking a Story trope removes only that Story annotation" do
    story = stories(:story_one)
    assignment = story_tropes(:story_one_red_herring)

    assert_difference("StoryTrope.count", -1) do
      patch universe_story_url(universe_slug: @universe.slug, id: story), params: {
        story: {
          story_tropes_attributes: {
            "0" => { id: assignment.id, trope_slug: "red-herring", selected: "0", context_note: "" }
          }
        }
      }
    end

    assert_redirected_to universe_story_url(universe_slug: @universe.slug, id: story)
  end

  test "a trope annotation in draft mode is remembered and applied with its context" do
    @universe.update!(collaboration_mode: "wikipedia")
    story = stories(:story_alt)

    assert_difference("DraftChange.count") do
      patch universe_story_url(universe_slug: @universe.slug, id: story), params: {
        story: {
          story_tropes_attributes: {
            "0" => { trope_slug: "red-herring", selected: "1", context_note: "Remembered context." }
          }
        }
      }
    end

    change = DraftChange.order(:id).last
    assert_equal "Story", change.record_type
    assert change.payload.key?("story_tropes_attributes")

    get universe_draft_path(universe_slug: @universe.slug, id: change.draft)
    assert_response :success
    assert_includes response.body, "Trope annotations"
    assert_includes response.body, "Red Herring: Remembered context."
    assert_not_includes response.body, "story_tropes_attributes"

    DraftApplier.new(change.draft).apply

    assert_equal "Remembered context.", story.story_tropes.find_by!(trope_slug: "red-herring").context_note
  end

  test "Story creation in draft mode is not visible until the draft is applied" do
    @universe.update!(collaboration_mode: "wikipedia")

    assert_no_difference("Story.count") do
      assert_difference("DraftChange.count") do
        post universe_stories_url(universe_slug: @universe.slug), params: {
          story: {
            name: "Remembered story",
            story_tropes_attributes: {
              "0" => { trope_slug: "found-family", selected: "1", context_note: "A draft annotation." }
            }
          }
        }
      end
    end

    change = DraftChange.order(:id).last
    assert_equal "create", change.action
    DraftApplier.new(change.draft).apply

    story = @universe.stories.find_by!(name: "Remembered story")
    assert_equal "A draft annotation.", story.story_tropes.find_by!(trope_slug: "found-family").context_note
  end

  test "Story deletion in draft mode leaves the Story live until the draft is applied" do
    @universe.update!(collaboration_mode: "wikipedia")
    story = stories(:story_alt)

    assert_no_difference("Story.count") do
      assert_difference("DraftChange.count") do
        delete universe_story_url(universe_slug: @universe.slug, id: story)
      end
    end

    change = DraftChange.order(:id).last
    assert_equal "delete", change.action
    assert_nil Story.unscoped.find(story.id).deleted_at
    DraftApplier.new(change.draft).apply
    assert Story.unscoped.find(story.id).deleted_at.present?
  end

  test "should update story" do
    story = stories(:story_alt)

    patch universe_story_url(universe_slug: @universe.slug, id: story),
      params: { story: { name: "Renamed spin-off", description: "Updated" } }

    assert_redirected_to universe_story_url(universe_slug: @universe.slug, id: story)
    story.reload
    assert_equal [ "Renamed spin-off", "Updated" ], [ story.name, story.description ]
  end

  test "should destroy story and its sections" do
    story = stories(:story_one)

    assert_difference("Story.count", -1) do
      assert_difference("Section.count", -2) do
        delete universe_story_url(universe_slug: @universe.slug, id: story)
      end
    end

    assert_redirected_to universe_stories_url(universe_slug: @universe.slug)
  end

  test "cannot reach a story belonging to another universe" do
    get universe_story_url(universe_slug: @universe.slug, id: stories(:story_two))

    assert_response :not_found
  end

  test "story show states the story's whole prose total" do
    get universe_story_url(universe_slug: @universe.slug, id: stories(:story_one))

    assert_response :success
    assert_includes response.body, "38 words"
  end
end
