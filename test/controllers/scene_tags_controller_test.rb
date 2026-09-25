require "test_helper"

class SceneTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @scene_tag = scene_tags(:scene_tag_one)
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  def scene_tags_url_for(story = @story)
    universe_story_scene_tags_url(universe_slug: @universe.slug, story_id: story)
  end

  def scene_tag_url_for(tag, story = @story)
    universe_story_scene_tag_url(universe_slug: @universe.slug, story_id: story, id: tag)
  end

  test "gets the story-scoped taxonomy index" do
    get scene_tags_url_for

    assert_response :success
    assert_select "h1", text: "Scene tags"
    assert_select ".taxonomy-node", 2
    assert_select ".tag-taxonomy-tabs a", text: "Scene tags"
  end

  test "index only lists scene tags of the current story" do
    stories(:story_alt).scene_tags.create!(name: "Alt story tag")

    get scene_tags_url_for(stories(:story_alt))

    assert_response :success
    assert_includes response.body, "Alt story tag"
    assert_not_includes response.body, "Scene tag one"
  end

  test "creates a scene tag as json for inline editing" do
    assert_difference("SceneTag.count") do
      post scene_tags_url_for,
        params: { scene_tag: { name: "Inline scene tag", parent_id: @scene_tag.id } },
        as: :json
    end

    assert_response :created
    assert_equal "Inline scene tag", response.parsed_body["name"]
    assert_equal @scene_tag.id, response.parsed_body["parent_id"]
    created_tag = SceneTag.order(:id).last
    assert_equal @story, created_tag.story
    assert_equal universe_story_scene_tag_path(universe_slug: @universe.slug, story_id: @story, id: created_tag), response.parsed_body["url"]
  end

  test "updates and destroys a scene tag as json" do
    patch scene_tag_url_for(@scene_tag),
      params: { scene_tag: { name: "Renamed scene tag", description: "Scene beat" } },
      as: :json

    assert_response :success
    assert_equal "Renamed scene tag", response.parsed_body["name"]
    assert_equal "Scene beat", response.parsed_body["description"]

    assert_difference("SceneTag.count", -1) do
      delete scene_tag_url_for(scene_tags(:scene_tag_two)), as: :json
    end
    assert_response :no_content
  end

  test "moves a scene tag through the shared positioned resource contract" do
    parent = SceneTag.create!(story: @story, name: "Parent")
    first = SceneTag.create!(story: @story, name: "First", parent: parent, position: 0)
    second = SceneTag.create!(story: @story, name: "Second", parent: parent, position: 1)

    patch scene_tag_url_for(second),
      params: { scene_tag: { position: 0 } },
      as: :json

    assert_response :success
    assert_equal [ second, first ], parent.children.reload.to_a
    assert_equal [ 0, 1 ], parent.children.order(:position, :id).pluck(:position)
  end

  test "cannot manage a scene tag through another story" do
    patch scene_tag_url_for(@scene_tag, stories(:story_alt)),
      params: { scene_tag: { name: "Hijacked" } },
      as: :json

    assert_response :not_found
    assert_equal "Scene tag one", @scene_tag.reload.name
  end

  test "does not accept an HTML taxonomy mutation" do
    assert_no_difference("SceneTag.count") do
      post scene_tags_url_for, params: { scene_tag: { name: "HTML tag" } }
    end

    assert_response :not_acceptable
  end

  test "there is no universe-level Scene Tag route" do
    get "/u/#{@universe.slug}/scene_tags"

    assert_response :not_found
  end

  test "guests can read a public story taxonomy but must sign in to mutate it" do
    sign_out

    get scene_tags_url_for
    assert_response :success

    assert_no_difference("SceneTag.count") do
      post scene_tags_url_for,
        params: { scene_tag: { name: "Guest tag" } },
        as: :json
    end
    assert_redirected_to new_session_url
  end

  test "private taxonomy follows the universe read and write policy" do
    owner = users(:user_one)
    reader = users(:user_two)
    universe = Universe.create!(owner: owner, name: "Private scene tags", slug: "private-scene-tags", private: true)
    story = Story.create!(universe: universe, name: "Private story")
    tag = story.scene_tags.create!(name: "Private tag")
    UniverseMembership.create!(universe: universe, user: reader, access_level: :read)

    sign_out
    sign_in_as(reader)

    get universe_story_scene_tags_url(universe_slug: universe.slug, story_id: story)
    assert_response :success

    patch universe_story_scene_tag_url(universe_slug: universe.slug, story_id: story, id: tag),
      params: { scene_tag: { name: "Reader rename" } },
      as: :json
    assert_response :forbidden

    writer = User.create!(name: "Scene tag writer", email_address: "scene-tag-writer@example.com", password: "password")
    UniverseMembership.create!(universe: universe, user: writer, access_level: :write)
    sign_out
    sign_in_as(writer)
    post universe_story_scene_tags_url(universe_slug: universe.slug, story_id: story),
      params: { scene_tag: { name: "Writer tag" } },
      as: :json
    assert_response :created

    sign_out
    get universe_story_scene_tags_url(universe_slug: universe.slug, story_id: story)
    assert_response :not_found
  end
end
