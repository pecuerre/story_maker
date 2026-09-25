require "test_helper"

class SectionPathsTest < ActiveSupport::TestCase
  setup do
    @story = stories(:story_one)
  end

  test "builds root-first ancestor paths and depth-indented options from one list" do
    paths = SectionPaths.build(@story.sections.reorder(:position, :id).to_a)

    assert_equal "Section one", paths.label_for(sections(:section_one))
    assert_equal "Section one / Section two", paths.label_for(sections(:section_two))
    assert_equal [ [ "Ungrouped", "" ], [ "Section one", sections(:section_one).id ],
      [ "— Section two", sections(:section_two).id ] ], paths.grouping_options
  end

  test "accepts a section id as well as a record" do
    paths = SectionPaths.build(@story.sections.reorder(:position, :id).to_a)

    assert_equal "Section one / Section two", paths.label_for(sections(:section_two).id)
    assert_nil paths.label_for(nil)
    assert_nil paths.label_for("")
  end

  test "an ungrouped scene has no label" do
    paths = SectionPaths.build(@story.sections.reorder(:position, :id).to_a)

    assert_nil paths.label_for(scenes(:scene_three).section_id)
  end

  test "an empty story still offers the ungrouped option" do
    paths = SectionPaths.build([])

    assert_equal [ [ "Ungrouped", "" ] ], paths.grouping_options
    assert_nil paths.label_for(1)
  end

  test "a corrupt parent cycle terminates instead of recursing forever" do
    root = @story.sections.create!(name: "Root")
    child = @story.sections.create!(name: "Child", parent: root)
    child.update_column(:parent_id, root.id)
    root.update_column(:parent_id, child.id)

    paths = SectionPaths.build([ root, child ])

    # Neither node is a root any more, so nothing is offered rather than looping.
    assert_equal [ [ "Ungrouped", "" ] ], paths.grouping_options
    assert_nil paths.label_for(root)
  end
end
