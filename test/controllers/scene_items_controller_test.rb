require "test_helper"

# The Items tab is a real read page (guests and read-only members see it), while
# its mutations are JSON-only (ADR 0011). Unlike the Characters tab there is only
# one participation source, so every row is a stored presence link with a role.
class SceneItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
    @path = universe_story_scene_scene_items_path(universe_slug: @universe.slug,
      story_id: @story, scene_id: @scene)
    sign_in_as(users(:user_one))
  end

  def private_scene
    universe = Universe.create!(owner: users(:user_one), name: "Private props", slug: "private-props", private: true)
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

  test "the tab lists every linked item with its role" do
    get @path

    assert_response :success
    assert_equal [ "Item one", "Item two" ], listed_names
    assert_includes response.body, "Role: carries"
    # A blank role is a real state, not a missing value.
    assert_includes response.body, "No role recorded"
  end

  test "the picker offers every universe item and a duplicate is refused" do
    third = @universe.items.create!(name: "Third")

    get @path

    assert_response :success
    # The blank prompt plus every universe item.
    assert_select "select[name='scene_item[item_id]'] option", count: 4
    assert_select "select[name='scene_item[item_id]'] option[value='']", text: "Choose an item"
    assert_select "select[name='scene_item[item_id]'] option[value=?]", third.id
    # An item already in the scene is not hidden, because a stale page or a
    # second window can submit one anyway; the model reports it as an error.
    assert_select "select[name='scene_item[item_id]'] option[value=?]", items(:item_one).id
    assert_no_difference("SceneItem.count") do
      post @path, params: { scene_item: { item_id: items(:item_one).id } }, as: :json
    end
    assert_response :unprocessable_content
    assert_equal [ "is already in this scene" ], response.parsed_body["item_id"]
  end

  test "an empty scene says how an item can end up on the tab" do
    empty = @story.scenes.create!(name: "Empty scene")

    get universe_story_scene_scene_items_path(universe_slug: @universe.slug, story_id: @story, scene_id: empty)

    assert_response :success
    assert_select ".empty-title", text: "No items in this scene yet"
    assert_select ".empty-description", text: /shared by every story/
  end

  test "creates a presence link with an optional role" do
    new_item = @universe.items.create!(name: "Third")

    assert_difference("SceneItem.count", 1) do
      post @path, params: { scene_item: { item_id: new_item.id, role: "carries" } }, as: :json
    end

    assert_response :created
    link = @scene.scene_items.order(:id).last
    assert_equal new_item, link.item
    assert_equal "carries", link.role
    assert_equal new_item.id, response.parsed_body["item_id"]
  end

  test "a blank role is stored as no role" do
    new_item = @universe.items.create!(name: "Fourth")

    post @path, params: { scene_item: { item_id: new_item.id, role: "" } }, as: :json

    assert_response :created
    assert_nil @scene.scene_items.order(:id).last.role
  end

  test "a duplicate link is an ordinary 422 even when a stale page submits one" do
    assert_no_difference("SceneItem.count") do
      post @path, params: { scene_item: { item_id: items(:item_one).id } }, as: :json
    end

    assert_response :unprocessable_content
    assert_equal [ "is already in this scene" ], response.parsed_body["item_id"]
  end

  test "an update can repoint a link at another item in the same universe" do
    link = scene_items(:scene_item_one)
    original = link.item

    patch universe_story_scene_scene_item_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link),
      params: { scene_item: { item_id: original.id, role: "on the table" } }, as: :json

    assert_response :success
    assert_equal original, link.reload.item
    assert_equal "on the table", link.role
  end

  test "repointing a link at an item that is already in the scene is a 422" do
    link = scene_items(:scene_item_one)

    patch universe_story_scene_scene_item_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_item: { item_id: items(:item_two).id } }, as: :json

    assert_response :unprocessable_content
    assert_equal [ "is already in this scene" ], response.parsed_body["item_id"]
    assert_equal items(:item_one), link.reload.item
  end

  test "a role-only update leaves the item alone" do
    link = scene_items(:scene_item_one)

    patch universe_story_scene_scene_item_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_item: { role: "left on the table" } }, as: :json

    assert_response :success
    assert_equal items(:item_one), link.reload.item
    assert_equal "left on the table", link.role
  end

  test "a blank item on an update means keep the current one" do
    link = scene_items(:scene_item_one)

    patch universe_story_scene_scene_item_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_item: { item_id: "", role: "stays" } }, as: :json

    assert_response :success
    assert_equal items(:item_one), link.reload.item
    assert_equal "stays", link.role
  end

  test "an item from another universe is not found" do
    outsider = universes(:universe_two).items.create!(name: "Outsider")

    assert_no_difference("SceneItem.count") do
      post @path, params: { scene_item: { item_id: outsider.id } }, as: :json
    end

    assert_response :not_found
  end

  test "an unknown item is not found rather than a foreign key error" do
    assert_no_difference("SceneItem.count") do
      post @path, params: { scene_item: { item_id: 0 } }, as: :json
    end

    assert_response :not_found
  end

  test "a missing item is a bad request" do
    assert_no_difference("SceneItem.count") do
      post @path, params: { scene_item: { role: "carries" } }, as: :json
    end

    assert_response :bad_request
  end

  test "an update with no editable field is a bad request" do
    assert_no_difference("SceneItem.count") do
      patch universe_story_scene_scene_item_path(universe_slug: @universe.slug, story_id: @story,
        scene_id: @scene, id: scene_items(:scene_item_one)), params: { scene_item: {} }, as: :json
    end

    assert_response :bad_request
  end

  test "edits the role and reports the new value" do
    link = scene_items(:scene_item_one)

    patch universe_story_scene_scene_item_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_item: { role: "left on the table" } }, as: :json

    assert_response :success
    assert_equal "left on the table", link.reload.role
    assert_equal "left on the table", response.parsed_body["role"]
  end

  test "clears a role by sending a blank one" do
    link = scene_items(:scene_item_one)

    patch universe_story_scene_scene_item_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_item: { role: "  " } }, as: :json

    assert_response :success
    assert_nil link.reload.role
  end

  test "removing a link keeps the item and every other scene that uses it" do
    link = scene_items(:scene_item_one)
    item = link.item

    assert_difference("SceneItem.count", -1) do
      delete universe_story_scene_scene_item_path(universe_slug: @universe.slug, story_id: @story,
        scene_id: @scene, id: link), as: :json
    end

    assert_response :no_content
    assert Item.exists?(item.id)
    # The same item is linked into a second scene, which is the shared-universe
    # point: withdrawing one Scene's claim never touches another's.
    assert_equal [ scene_items(:scene_item_three).id ], item.scene_items.pluck(:id)
  end

  test "an html mutation is refused before anything is written" do
    assert_no_difference("SceneItem.count") do
      post @path, params: { scene_item: { item_id: items(:item_one).id } }
    end
    assert_response :not_acceptable

    link = scene_items(:scene_item_one)
    patch universe_story_scene_scene_item_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: link), params: { scene_item: { role: "html" } }
    assert_response :not_acceptable

    assert_no_difference("SceneItem.count") do
      delete universe_story_scene_scene_item_path(universe_slug: @universe.slug, story_id: @story,
        scene_id: @scene, id: link)
    end
    assert_response :not_acceptable

    assert_equal "carries", link.reload.role
  end

  test "guests can read the tab and are sent to sign in to change it" do
    sign_out

    get @path

    assert_response :success
    assert_equal [ "Item one", "Item two" ], listed_names
    assert_select "button[data-action='modal-form#open']", count: 0
    assert_select "button[data-action='modal-form#destroy']", count: 0
    assert_select "[data-modal-form-target='errors']", count: 0

    assert_no_difference("SceneItem.count") do
      post @path, params: { scene_item: { item_id: items(:item_one).id } }, as: :json
    end
    assert_redirected_to new_session_url
  end

  test "read-only members see the tab without any control" do
    universe, story, scene = private_scene
    scene.scene_items.create!(item: universe.items.create!(name: "Reader's prop"), role: "carries")
    sign_in_read_only_member(universe)

    get universe_story_scene_scene_items_path(universe_slug: universe.slug, story_id: story, scene_id: scene)

    assert_response :success
    assert_equal [ "Reader's prop" ], listed_names
    assert_select "button[data-action='modal-form#open']", count: 0
    assert_select "button[data-action='modal-form#destroy']", count: 0
    assert_select "[data-controller='modal-form']", count: 0

    link = scene.scene_items.first
    patch universe_story_scene_scene_item_path(universe_slug: universe.slug, story_id: story,
      scene_id: scene, id: link), params: { scene_item: { role: "hijacked" } }, as: :json
    assert_response :forbidden

    assert_no_difference("SceneItem.count") do
      delete universe_story_scene_scene_item_path(universe_slug: universe.slug, story_id: story,
        scene_id: scene, id: link), as: :json
    end
    assert_response :forbidden

    assert_equal "carries", link.reload.role
  end

  test "a private universe tab stays hidden from non-members and guests" do
    universe, story, scene = private_scene

    sign_in_as(users(:user_two))
    get universe_story_scene_scene_items_path(universe_slug: universe.slug, story_id: story, scene_id: scene)
    assert_response :not_found

    sign_out
    get universe_story_scene_scene_items_path(universe_slug: universe.slug, story_id: story, scene_id: scene)
    assert_response :not_found
  end

  test "a link cannot be managed through another scene, story, or universe" do
    link = scene_items(:scene_item_one)

    patch universe_story_scene_scene_item_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: scenes(:scene_three), id: link), params: { scene_item: { role: "hijacked" } }, as: :json
    assert_response :not_found

    patch universe_story_scene_scene_item_path(universe_slug: @universe.slug, story_id: stories(:story_alt),
      scene_id: scenes(:scene_alt), id: link), params: { scene_item: { role: "hijacked" } }, as: :json
    assert_response :not_found

    delete universe_story_scene_scene_item_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: scenes(:scene_three), id: link), as: :json
    assert_response :not_found

    assert_equal "carries", link.reload.role
  end
end
