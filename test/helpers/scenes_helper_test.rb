require "test_helper"

class ScenesHelperTest < ActionView::TestCase
  include ScenesHelper

  test "reports the section group or the ungrouped state" do
    story = stories(:story_one)
    paths = SectionPaths.build(story.sections.reorder(:position, :id).to_a)

    assert_equal "Section one / Section two", scene_grouping_label(scenes(:scene_two), paths)
    assert_nil scene_grouping_label(scenes(:scene_three), paths)

    assert_equal "Ungrouped", scene_grouping_label_by_id(paths, nil)
    assert_equal "Section one", scene_grouping_label_by_id(paths, sections(:section_one).id)
  end

  test "keeps a rejected in-world time in the field value" do
    scene = Scene.new(story: stories(:story_one), name: "Bad time", datetime: "not-a-datetime")

    assert_equal "not-a-datetime", scene_datetime_field_value(scene)
    assert_equal "2026-09-11T09:00", scene_datetime_field_value(scenes(:scene_one))
    assert_nil scene_datetime_field_value(Scene.new(story: stories(:story_one), name: "No time"))
  end

  test "offers an explicit none choice plus every universe event" do
    choices = scene_event_choices(universe_events)

    assert_equal [ "None", "" ], choices.first
    assert_includes choices.map(&:first), events(:event_one).display_string
  end

  test "formats the in-world time with minute precision and no value when unset" do
    assert_equal "2026-09-11 09:00", scene_in_world_time(scenes(:scene_one))
    assert_nil scene_in_world_time(Scene.new(story: stories(:story_one), name: "No time"))
  end

  test "offers Scene Tag paths in root-first order" do
    tags = [ scene_tags(:scene_tag_two), scene_tags(:scene_tag_one) ]

    assert_equal [
      [ "Scene tag one", scene_tags(:scene_tag_one).id ],
      [ "Scene tag one / Scene tag two", scene_tags(:scene_tag_two).id ]
    ], scene_tag_choices(tags)
  end

  test "describes the filters in effect with readable labels" do
    story = stories(:story_one)
    section_paths = SectionPaths.build(story.sections.reorder(:position, :id).to_a)
    tag_paths = SceneTagPaths.build(story.scene_tags.order(:position, :id).to_a)

    assert_empty scene_filter_summaries(filter_for(story, section_paths), section_paths, tag_paths)
    assert_equal [ "Search: “cave”" ], scene_filter_summaries(
      filter_for(story, section_paths, q: "cave"), section_paths, tag_paths
    )
    assert_equal [ "Section: Ungrouped" ],
      scene_filter_summaries(filter_for(story, section_paths, section_id: SceneFilter::UNGROUPED), section_paths, tag_paths)
    assert_equal [ "Section: Section one / Section two", "Scene tag: Scene tag one / Scene tag two",
      "In-world from 1986-01-01", "In-world to 1986-12-31" ], scene_filter_summaries(
      filter_for(story, section_paths, section_id: sections(:section_two).id,
        scene_tag_id: scene_tags(:scene_tag_two).id, from: "1986-01-01", to: "1986-12-31"),
      section_paths, tag_paths
    )
  end

  private
    def universe_events
      @universe_events ||= universes(:universe_one).events.reorder(:name, :id).to_a
    end

    def filter_for(story, section_paths, **params)
      SceneFilter.new(params, section_ids: section_paths.ids,
        scene_tags: story.scene_tags.order(:position, :id).to_a)
    end
end
