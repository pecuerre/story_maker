require "test_helper"

class PositionedResourceOrderTest < ActiveSupport::TestCase
  setup do
    @story = stories(:story_one)
    @other_story = stories(:story_alt)
    @parent = sections(:section_one)
    @existing_child = sections(:section_two)
    @existing_child.update_column(:position, 0)
  end

  test "creates at the requested sibling position and normalizes the group" do
    resource = @story.sections.new(name: "Inserted child")

    assert PositionedResourceOrder.create(
      resource,
      @story.sections,
      scope_owner: @story,
      parent_id: @parent.id,
      requested_position: 0,
      hierarchical: true
    )

    assert_equal 0, resource.position
    assert_equal [ resource, @existing_child ], @parent.children.reload.to_a
    assert_equal [ 0, 1 ], @parent.children.pluck(:position)
  end

  test "appends when no position is requested" do
    resource = @story.sections.new(name: "Appended child")

    assert PositionedResourceOrder.create(
      resource,
      @story.sections,
      scope_owner: @story,
      parent_id: @parent.id,
      hierarchical: true
    )

    assert_equal 1, resource.position
  end

  test "moves a resource within its sibling group transactionally" do
    second = @story.sections.create!(name: "Second child", story: @story, parent: @parent, position: 1)
    second.update_column(:position, 1)

    assert PositionedResourceOrder.update(
      second,
      ActionController::Parameters.new(position: 0).permit!,
      @story.sections,
      scope_owner: @story,
      hierarchical: true
    )

    assert_equal [ second, @existing_child ], @parent.children.reload.to_a
    assert_equal [ 0, 1 ], @parent.children.pluck(:position)
  end

  test "moves a resource to another parent and normalizes both groups" do
    root = @story.sections.create!(name: "Root sibling", story: @story, position: 1)
    root.update_column(:position, 1)

    assert PositionedResourceOrder.update(
      @existing_child,
      ActionController::Parameters.new(parent_id: nil, position: 0).permit!,
      @story.sections,
      scope_owner: @story,
      hierarchical: true
    )

    assert_nil @existing_child.reload.parent_id
    assert_equal 0, @existing_child.position
    assert_equal 2, root.reload.position
  end

  test "destroying a sibling closes the position gap" do
    second = @story.sections.create!(name: "Second child", story: @story, parent: @parent, position: 1)
    second.update_column(:position, 1)
    third = @story.sections.create!(name: "Third child", story: @story, parent: @parent, position: 2)
    third.update_column(:position, 2)

    assert PositionedResourceOrder.destroy(
      @existing_child,
      @story.sections,
      scope_owner: @story,
      parent_id: @parent.id,
      hierarchical: true
    )

    assert_equal [ second, third ], @parent.children.reload.to_a
    assert_equal [ 0, 1 ], @parent.children.pluck(:position)
  end

  test "direct hierarchical destroys also close sibling gaps" do
    second = @story.sections.create!(name: "Second child", story: @story, parent: @parent, position: 1)
    second.update_column(:position, 1)

    @existing_child.destroy!

    assert_equal [ second ], @parent.children.reload.to_a
    assert_equal 0, second.reload.position
  end

  test "validation failures roll back attribute and position changes" do
    original_name = @existing_child.name
    original_position = @existing_child.position

    result = PositionedResourceOrder.update(
      @existing_child,
      ActionController::Parameters.new(name: "", position: 1).permit!,
      @story.sections,
      scope_owner: @story,
      hierarchical: true
    )

    assert_not result
    assert_equal original_name, @existing_child.reload.name
    assert_equal original_position, @existing_child.position
  end

  test "flat mode does not require a parent attribute" do
    flat_resource = @story.sections.new(name: "Flat record")

    assert PositionedResourceOrder.create(
      flat_resource,
      @story.sections,
      scope_owner: @story,
      parent_id: nil,
      hierarchical: false
    )

    assert_equal @story.sections.count - 1, flat_resource.position
  end

  test "flat mode orders a parentless story sequence contiguously" do
    story = Story.create!(universe: universes(:universe_one), name: "Flat sequence story")
    first = story.scenes.new(name: "First")
    second = story.scenes.new(name: "Second")

    assert PositionedResourceOrder.create(first, story.scenes, scope_owner: story, parent_id: nil, hierarchical: false)
    assert PositionedResourceOrder.create(second, story.scenes, scope_owner: story, parent_id: nil, hierarchical: false)

    assert_equal 0, first.position
    assert_equal 1, second.position
    assert_not Scene.column_names.include?("parent_id")

    assert PositionedResourceOrder.update(
      second,
      ActionController::Parameters.new(position: 0).permit!,
      story.scenes,
      scope_owner: story,
      hierarchical: false
    )

    assert_equal [ second, first ], story.scenes.reorder(:position, :id).to_a
    assert_equal [ 0, 1 ], story.scenes.reorder(:position, :id).pluck(:position)
  end

  test "destroying a flat record closes the gap and leaves other scopes untouched" do
    story = Story.create!(universe: universes(:universe_one), name: "Flat destroy story")
    other_story = Story.create!(universe: universes(:universe_one), name: "Other flat story")
    other_child = other_story.scenes.create!(name: "Other child", position: 0)
    first = story.scenes.create!(name: "First", position: 0)
    second = story.scenes.create!(name: "Second", position: 1)

    assert PositionedResourceOrder.destroy(first, story.scenes, scope_owner: story, parent_id: nil, hierarchical: false)

    assert_equal [ second ], story.scenes.reorder(:position, :id).to_a
    assert_equal 0, second.reload.position
    assert_equal 0, other_child.reload.position
  end

  test "a flat validation failure leaves every position untouched" do
    story = Story.create!(universe: universes(:universe_one), name: "Flat validation story")
    scene = story.scenes.create!(name: "Only scene", position: 0)

    result = PositionedResourceOrder.update(
      scene,
      ActionController::Parameters.new(name: "").permit!,
      story.scenes,
      scope_owner: story,
      hierarchical: false
    )

    assert_not result
    assert_equal "Only scene", scene.reload.name
    assert_equal [ 0 ], story.scenes.reorder(:position, :id).pluck(:position)
  end

  test "ordering is isolated by scope owner" do
    other_child = @other_story.sections.create!(name: "Other child", story: @other_story, position: 0)
    resource = @story.sections.new(name: "Scoped child")

    assert PositionedResourceOrder.create(
      resource,
      @story.sections,
      scope_owner: @story,
      parent_id: @parent.id,
      hierarchical: true
    )

    assert_equal 0, other_child.reload.position
    assert_equal 1, resource.position
  end
end
