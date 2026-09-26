require "test_helper"

# The Characters tab is a real read page (guests and read-only members see it),
# while its mutations are JSON-only (ADR 0011). The page shows the union of
# stored presence links and derived Dialogue speakers and labels the difference,
# so a speaker is never a second stored row and never a second count.
class SceneCharactersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
    @path = universe_story_scene_scene_characters_path(universe_slug: @universe.slug,
      story_id: @story, scene_id: @scene)
    sign_in_as(users(:user_one))
  end

  def private_scene
    universe = Universe.create!(owner: users(:user_one), name: "Private cast", slug: "private-cast", private: true)
    story = Story.create!(universe: universe, name: "Private story")
    [ universe, story, story.scenes.create!(name: "Private scene") ]
  end

  def sign_in_read_only_member(universe)
    UniverseMembership.create!(universe: universe, user: users(:user_two), access_level: :read)
    sign_out
    sign_in_as(users(:user_two))
  end

  def listed_names
    css_select(".entity-list .entity-title").map { |title| title.text.squish }
  end

  test "the tab lists stored participants and derived speakers once each" do
    get @path

    assert_response :success
    # Both characters are stored participants of this scene and both speak in
    # `dialogue_one`; the union is still two rows, not four.
    assert_equal [ "Character one", "Character two" ], listed_names
    assert_select ".entity-list .badge", text: "Participant"
    assert_select ".entity-list .badge", text: "Speaks in 1 element"
  end

  test "the tab shows the role and names the elements a character speaks in" do
    get @path

    assert_response :success
    assert_includes response.body, "Role: setting"
    assert_includes response.body, "No role recorded"
    assert_includes response.body, "Speaks in Michael teaches the waltz."
  end

  test "a character who only speaks is listed without a stored record" do
    outsider = @universe.characters.create!(name: "Passer-by")
    scene = @story.scenes.create!(name: "Street")
    scene.scene_elements.create!(name: "Passing", kind: "dialogue", characters: [ outsider ])

    get universe_story_scene_scene_characters_path(universe_slug: @universe.slug, story_id: @story, scene_id: scene)

    assert_response :success
    assert_equal [ "Passer-by" ], listed_names
    assert_select ".entity-list .badge", text: "Participant", count: 0
    assert_select "button[data-action='modal-form#open']", count: 1, message: "only the add action is offered"
    assert_select "button[data-action='modal-form#destroy']", count: 0
  end

  test "the picker offers every universe character and a duplicate is refused" do
    third = @universe.characters.create!(name: "Third")

    get @path

    assert_response :success
    # The blank prompt plus every universe character.
    assert_select "select[name='scene_character[character_id]'] option", count: 4
    assert_select "select[name='scene_character[character_id]'] option[value='']", text: "Choose a character"
    assert_select "select[name='scene_character[character_id]'] option[value=?]", third.id
    # A character already in the scene is not hidden, because a stale page or a
    # second window can submit one anyway; the model reports it as an error.
    assert_select "select[name='scene_character[character_id]'] option[value=?]", characters(:character_one).id
    assert_no_difference("SceneCharacter.count") do
      post @path, params: { scene_character: { character_id: characters(:character_one).id } }, as: :json
    end
    assert_response :unprocessable_content
    assert_equal [ "is already in this scene" ], response.parsed_body["character_id"]
  end

  test "an empty scene says how a character can end up on the tab" do
    empty = @story.scenes.create!(name: "Empty scene")

    get universe_story_scene_scene_characters_path(universe_slug: @universe.slug, story_id: @story, scene_id: empty)

    assert_response :success
    assert_select ".empty-title", text: "No characters in this scene yet"
    assert_select ".empty-description", text: /without a separate record/
  end

  test "creates a presence link with an optional role" do
    new_character = @universe.characters.create!(name: "Third")

    assert_difference("SceneCharacter.count", 1) do
      post @path, params: { scene_character: { character_id: new_character.id, role: "enters" } }, as: :json
    end

    assert_response :created
    link = @scene.scene_characters.order(:id).last
    assert_equal new_character, link.character
    assert_equal "enters", link.role
    assert_equal new_character.id, response.parsed_body["character_id"]
  end

  test "a blank role is stored as no role" do
    new_character = @universe.characters.create!(name: "Fourth")

    post @path, params: { scene_character: { character_id: new_character.id, role: "" } }, as: :json

    assert_response :created
    assert_nil @scene.scene_characters.order(:id).last.role
  end

  test "a duplicate link is an ordinary 422 even when a stale page submits one" do
    assert_no_difference("SceneCharacter.count") do
      post @path, params: { scene_character: { character_id: characters(:character_one).id } }, as: :json
    end

    assert_response :unprocessable_content
    assert_equal [ "is already in this scene" ], response.parsed_body["character_id"]
  end

  test "an update can repoint a link at another character in the same universe" do
    link = scene_characters(:scene_character_one)
    original = link.character

    patch universe_story_scene_scene_character_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link),
      params: { scene_character: { character_id: original.id, role: "enters" } }, as: :json

    assert_response :success
    assert_equal original, link.reload.character
    assert_equal "enters", link.role
  end

  test "repointing a link at a character that is already in the scene is a 422" do
    link = scene_characters(:scene_character_one)

    patch universe_story_scene_scene_character_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link),
      params: { scene_character: { character_id: characters(:character_two).id } }, as: :json

    assert_response :unprocessable_content
    assert_equal [ "is already in this scene" ], response.parsed_body["character_id"]
    assert_equal characters(:character_one), link.reload.character
  end

  test "a role-only update leaves the character alone" do
    link = scene_characters(:scene_character_one)

    patch universe_story_scene_scene_character_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_character: { role: "carries the box" } }, as: :json

    assert_response :success
    assert_equal characters(:character_one), link.reload.character
    assert_equal "carries the box", link.role
  end

  test "a blank character on an update means keep the current one" do
    link = scene_characters(:scene_character_one)

    patch universe_story_scene_scene_character_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_character: { character_id: "", role: "stays" } }, as: :json

    assert_response :success
    assert_equal characters(:character_one), link.reload.character
    assert_equal "stays", link.role
  end

  test "a character from another universe is not found" do
    outsider = universes(:universe_two).characters.create!(name: "Outsider")

    assert_no_difference("SceneCharacter.count") do
      post @path, params: { scene_character: { character_id: outsider.id } }, as: :json
    end

    assert_response :not_found
  end

  test "an unknown character is not found rather than a foreign key error" do
    assert_no_difference("SceneCharacter.count") do
      post @path, params: { scene_character: { character_id: 0 } }, as: :json
    end

    assert_response :not_found
  end

  test "a missing character is a bad request" do
    assert_no_difference("SceneCharacter.count") do
      post @path, params: { scene_character: { role: "setting" } }, as: :json
    end

    assert_response :bad_request
  end

  test "an update with no editable field is a bad request" do
    assert_no_difference("SceneCharacter.count") do
      patch universe_story_scene_scene_character_path(universe_slug: @universe.slug, story_id: @story,
        scene_id: @scene, id: scene_characters(:scene_character_one)), params: { scene_character: {} }, as: :json
    end

    assert_response :bad_request
  end

  test "edits the role and reports the new value" do
    link = scene_characters(:scene_character_one)

    patch universe_story_scene_scene_character_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_character: { role: "carries the box" } }, as: :json

    assert_response :success
    assert_equal "carries the box", link.reload.role
    assert_equal "carries the box", response.parsed_body["role"]
  end

  test "clears a role by sending a blank one" do
    link = scene_characters(:scene_character_one)

    patch universe_story_scene_scene_character_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_character: { role: "  " } }, as: :json

    assert_response :success
    assert_nil link.reload.role
  end

  test "removing a link keeps the character and the dialogue speakers" do
    link = scene_characters(:scene_character_one)

    assert_difference("SceneCharacter.count", -1) do
      delete universe_story_scene_scene_character_path(universe_slug: @universe.slug, story_id: @story,
        scene_id: @scene, id: link), as: :json
    end

    assert_response :no_content
    assert Character.exists?(link.character_id)
    # Removing a presence link does not touch who speaks: the Dialogue still
    # names both characters, so the removed one is now only a speaker.
    assert_equal scene_elements(:dialogue_one).reload.character_ids.sort, [ characters(:character_one).id, characters(:character_two).id ].sort
    assert_equal 2, SceneParticipants.for(@scene).count
  end

  test "an html mutation is refused before anything is written" do
    assert_no_difference("SceneCharacter.count") do
      post @path, params: { scene_character: { character_id: characters(:character_one).id } }
    end
    assert_response :not_acceptable

    link = scene_characters(:scene_character_one)
    patch universe_story_scene_scene_character_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_character: { role: "html" } }
    assert_response :not_acceptable

    assert_no_difference("SceneCharacter.count") do
      delete universe_story_scene_scene_character_path(universe_slug: @universe.slug, story_id: @story,
        scene_id: @scene, id: link)
    end
    assert_response :not_acceptable

    assert_equal "setting", link.reload.role
  end

  test "guests can read the tab and are sent to sign in to change it" do
    sign_out

    get @path

    assert_response :success
    assert_equal [ "Character one", "Character two" ], listed_names
    assert_select "button[data-action='modal-form#open']", count: 0
    assert_select "button[data-action='modal-form#destroy']", count: 0
    assert_select "[data-modal-form-target='errors']", count: 0

    assert_no_difference("SceneCharacter.count") do
      post @path, params: { scene_character: { character_id: characters(:character_one).id } }, as: :json
    end
    assert_redirected_to new_session_url
  end

  test "read-only members see the tab without any control" do
    universe, story, scene = private_scene
    scene.scene_characters.create!(character: universe.characters.create!(name: "Reader"), role: "setting")
    sign_in_read_only_member(universe)

    get universe_story_scene_scene_characters_path(universe_slug: universe.slug, story_id: story, scene_id: scene)

    assert_response :success
    assert_equal [ "Reader" ], listed_names
    assert_select "button[data-action='modal-form#open']", count: 0
    assert_select "button[data-action='modal-form#destroy']", count: 0
    assert_select "[data-controller='modal-form']", count: 0

    link = scene.scene_characters.first
    patch universe_story_scene_scene_character_path(universe_slug: universe.slug, story_id: story,
      scene_id: scene, id: link), params: { scene_character: { role: "hijacked" } }, as: :json
    assert_response :forbidden

    assert_no_difference("SceneCharacter.count") do
      delete universe_story_scene_scene_character_path(universe_slug: universe.slug, story_id: story,
        scene_id: scene, id: link), as: :json
    end
    assert_response :forbidden

    assert_equal "setting", link.reload.role
  end

  test "a private universe tab stays hidden from non-members and guests" do
    universe, story, scene = private_scene

    sign_in_as(users(:user_two))
    get universe_story_scene_scene_characters_path(universe_slug: universe.slug, story_id: story, scene_id: scene)
    assert_response :not_found

    sign_out
    get universe_story_scene_scene_characters_path(universe_slug: universe.slug, story_id: story, scene_id: scene)
    assert_response :not_found
  end

  test "a link cannot be managed through another scene, story, or universe" do
    link = scene_characters(:scene_character_one)

    patch universe_story_scene_scene_character_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: scenes(:scene_three), id: link), params: { scene_character: { role: "hijacked" } }, as: :json
    assert_response :not_found

    patch universe_story_scene_scene_character_path(universe_slug: @universe.slug, story_id: stories(:story_alt),
      scene_id: scenes(:scene_alt), id: link), params: { scene_character: { role: "hijacked" } }, as: :json
    assert_response :not_found

    delete universe_story_scene_scene_character_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: scenes(:scene_three), id: link), as: :json
    assert_response :not_found

    assert_equal "setting", link.reload.role
  end
end
