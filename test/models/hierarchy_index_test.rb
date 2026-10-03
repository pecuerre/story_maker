require "test_helper"

class HierarchyIndexTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @region = @universe.locations.create!(name: "Winden", position: 0)
    @house = @universe.locations.create!(name: "Jonas House", position: 1, parent: @region)
    @room = @universe.locations.create!(name: "Jonas Room", position: 2, parent: @house)
    @index = HierarchyIndex.build(@universe.locations)
  end

  # The fixtures already hold places in this universe, so every assertion here is
  # about the three this test created rather than about the whole tree.
  test "answers the roots and every level of children from the rows it was given" do
    assert_equal [ @region ], @index.roots & [ @region ]
    assert_equal [ @house ], @index.children_of(@region)
    assert_equal [ @room ], @index.children_of(@house)
    assert_empty @index.children_of(@room)
  end

  test "children are ordered by position then id, the order the association scope uses" do
    later = @universe.locations.create!(name: "Drawn later", position: 9, parent: @region)
    earlier = @universe.locations.create!(name: "Drawn earlier", position: 0, parent: @region)
    tie = @universe.locations.create!(name: "Same position, later id", position: 1, parent: @region)

    children = HierarchyIndex.build(@universe.locations).children_of(@region)

    assert_equal [ earlier, @house, tie, later ], children
    # The association the index replaces answers in exactly this order.
    assert_equal children, @region.children.reload.to_a
  end

  test "accepts a bare id and answers an unknown one with no children" do
    assert_equal [ @house ], @index.children_of(@region.id)
    assert_empty @index.children_of(0)
  end

  # The roots are the children of nothing, which is how one method answers both
  # questions and why a nil parent cannot be asked about as an unknown id.
  test "no parent is the roots rather than an unknown id" do
    assert_equal @index.roots, @index.children_of(nil)
  end

  test "hands back one ordered list for callers that need every row" do
    assert_equal [ @region, @house, @room ], @index.records & [ @region, @house, @room ]
    assert_empty HierarchyIndex.build([]).roots
    assert_empty HierarchyIndex.build([]).records
  end

  test "a separate hierarchy is unaffected and its own rows are all it knows" do
    elsewhere = universes(:universe_two).locations.create!(name: "Elsewhere", position: 0)

    other = HierarchyIndex.build([ elsewhere ])

    assert_equal [ elsewhere ], other.roots
    assert_empty other.children_of(@region)
  end
end
