require "test_helper"

class ListFiltersHelperTest < ActionView::TestCase
  include ListFiltersHelper

  test "counts a filter's narrowing criteria but never the search or the order" do
    universe = universes(:universe_one)
    tag = character_tags(:character_tag_two)
    tags = universe.character_tags.to_a

    assert_equal 0, advanced_filter_count(CharacterFilter.new({}, character_tags: tags))
    assert_equal 0, advanced_filter_count(
      CharacterFilter.new({ q: "keeper" }, character_tags: tags)
    )
    assert_equal 0, advanced_filter_count(
      CharacterFilter.new({ sort: "created" }, character_tags: tags)
    )
    assert_equal 1, advanced_filter_count(
      CharacterFilter.new({ q: "keeper", character_tag_id: tag.id }, character_tags: tags)
    )
    assert_equal 1, advanced_filter_count(
      CharacterFilter.new({ character_tag_id: tag.id, sort: "created" }, character_tags: tags)
    )
  end

  test "counts every scene criterion, including both ends of a date range" do
    story = stories(:story_one)
    filter = SceneFilter.new(
      {
        q: "second",
        section_id: sections(:section_one).id,
        scene_tag_id: story.scene_tags.first&.id,
        status: "final",
        from: "2026-09-11",
        to: "2026-09-20"
      },
      section_ids: story.sections.ids,
      scene_tags: story.scene_tags.to_a
    )

    assert_equal 5, advanced_filter_count(filter)
  end
end
