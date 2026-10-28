require "test_helper"

class ManuscriptTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
  end

  test "scopes default to prose and reject an unknown value" do
    assert_equal "prose", Manuscript::DEFAULT_SCOPE
    assert_equal "prose", Manuscript.scope(nil)
    assert_equal "prose", Manuscript.scope("")
    assert_equal "prose", Manuscript.scope("screenplay")
    assert_equal "front_matter", Manuscript.scope("front_matter")
    assert_equal "bible", Manuscript.scope("bible")
    assert_equal %w[ prose front_matter bible ], Manuscript::SCOPES
  end

  test "builds the section tree and leaves ungrouped scenes aside" do
    manuscript = Manuscript.for(@story)

    root = manuscript.sections.first
    assert_equal sections(:section_one), root.section
    assert_equal 0, root.depth
    assert_equal [ scenes(:scene_one) ], root.scenes

    child = root.children.first
    assert_equal sections(:section_two), child.section
    assert_equal 1, child.depth
    assert_equal [ scenes(:scene_two) ], child.scenes
    assert_empty child.children

    assert_equal [ scenes(:scene_three) ], manuscript.ungrouped_scenes
  end

  test "scenes keep narrative order inside their section" do
    story = @universe.stories.create!(name: "Order story")
    section = story.sections.create!(name: "Act", position: 0)
    last = story.scenes.create!(name: "Last", section: section, position: 2)
    first = story.scenes.create!(name: "First", section: section, position: 0)
    middle = story.scenes.create!(name: "Middle", section: section, position: 1)

    manuscript = Manuscript.for(story)

    assert_equal [ first, middle, last ], manuscript.sections.first.scenes
  end

  test "a final-only manuscript prints only final scenes" do
    manuscript = Manuscript.for(@story, final_only: "1")

    assert manuscript.final_only?
    assert_equal [ scenes(:scene_one) ], manuscript.sections.first.scenes
    assert_empty manuscript.ungrouped_scenes
    assert_not manuscript.empty?
  end

  test "a final-only manuscript with no final scenes is empty" do
    story = @universe.stories.create!(name: "All drafts")
    story.scenes.create!(name: "Draft one", status: "draft")
    story.scenes.create!(name: "Draft two", status: "revised")

    assert Manuscript.for(story, final_only: true).empty?
    refute Manuscript.for(story).empty?
  end

  test "a scene whose section is not part of the story is printed ungrouped" do
    story = @universe.stories.create!(name: "Broken grouping")
    scene = story.scenes.create!(name: "Orphan")
    foreign_section = stories(:story_alt).sections.create!(name: "Another story's act")

    # The row still points at a real Section, so the foreign key holds, but that
    # Section is not part of this story's tree: the Scene reads as ungrouped
    # rather than disappearing from the book.
    scene.update_columns(section_id: foreign_section.id)

    assert_equal [ scene ], Manuscript.for(story).ungrouped_scenes
  end

  test "a scene under a detached section is printed ungrouped" do
    story = @universe.stories.create!(name: "Detached grouping")
    section = story.sections.create!(name: "Detached act")
    scene = story.scenes.create!(name: "Orphaned", section: section)
    foreign_parent = stories(:story_alt).sections.create!(name: "Another story's act")

    # The parent is a real Section, so the foreign key holds, but it is not in
    # this story's tree: the branch is never printed, and its Scene must not be
    # lost with it.
    section.update_columns(parent_id: foreign_parent.id)

    manuscript = Manuscript.for(story)

    assert_empty manuscript.sections
    assert_equal [ scene ], manuscript.ungrouped_scenes
  end

  test "prose is the default and carries no notes or appendices" do
    manuscript = Manuscript.for(@story)

    assert_equal "prose", manuscript.scope
    refute manuscript.scene_notes?
    refute manuscript.bible?
    assert_empty manuscript.appendices
  end

  test "front matter adds the scene notes without the universe appendices" do
    manuscript = Manuscript.for(@story, scope: "front_matter")

    assert_equal "front_matter", manuscript.scope
    assert manuscript.scene_notes?
    refute manuscript.bible?
    assert_empty manuscript.appendices
  end

  test "the bible scope carries the universe appendices in workspace order" do
    manuscript = Manuscript.for(@story, scope: "bible")
    appendices = manuscript.appendices

    assert manuscript.bible?
    assert manuscript.scene_notes?
    assert_equal %w[characters.title locations.title items.title events.title],
      appendices.map(&:label_key)

    character_appendix = appendices.first
    assert_equal :name, character_appendix.label_method
    assert_equal :at_a_glance, character_appendix.summary_method
    assert_includes character_appendix.records, characters(:character_three)

    event_appendix = appendices.last
    assert_equal :display_label, event_appendix.label_method
    assert_includes event_appendix.records, events(:event_one)
    assert_not_includes event_appendix.records, events(:event_other_universe)
  end

  test "an empty appendix category is left out" do
    empty_universe = Universe.create!(owner: users(:user_one), name: "Empty bible", slug: "empty-bible")
    story = empty_universe.stories.create!(name: "Nothing yet")

    assert_empty Manuscript.for(story, scope: "bible").appendices
  end

  test "soft-deleted scenes and elements are not part of the document" do
    scenes(:scene_three).soft_delete
    scene_elements(:narration_one).soft_delete

    manuscript = Manuscript.for(@story)

    assert_not_includes manuscript.ungrouped_scenes, scenes(:scene_three)
    assert_not_includes manuscript.sections.first.scenes.first.scene_elements, scene_elements(:narration_one)
  end
end
