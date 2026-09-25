require "test_helper"

# The Scenes list filter is a value object: it is worth covering on its own
# because the request tests can only show the outcome, not which part of the
# query produced it or what it did with a value it could not use.
class SceneFilterTest < ActiveSupport::TestCase
  setup do
    @story = stories(:story_one)
    @section_ids = section_ids
    @scene_tags = @story.scene_tags.order(:position, :id).to_a
  end

  test "an empty filter changes nothing and reports itself inactive" do
    filter = filter_for

    assert_not filter.active?
    assert_empty filter.query_params
    assert_empty filter.discarded
    assert_equal @story.scenes.reorder(:position, :id).to_a, apply(filter)
  end

  test "free text matches the title or the short description, ignoring case" do
    assert_equal [ scenes(:scene_two) ], apply(filter_for(q: "second"))
    assert_equal [ scenes(:scene_one) ], apply(filter_for(q: "FIRST SCENE"))
    # A scene tag or a grouping label is not searchable text.
    assert_empty apply(filter_for(q: "Scene tag one"))
  end

  test "search text is matched literally, so a wildcard is not a wildcard" do
    @story.scenes.create!(name: "100% of the truth", position: 3)

    assert_equal [ "100% of the truth" ], apply(filter_for(q: "100%")).map(&:name)
    assert_equal [ "100% of the truth" ], apply(filter_for(q: "%")).map(&:name),
      "a percent sign is text to search for, not a pattern matching everything"
  end

  test "the section filter accepts a section of this story and the ungrouped group" do
    assert_equal [ scenes(:scene_one) ], apply(filter_for(section_id: sections(:section_one).id.to_s))
    # A nested section is addressed directly; the path is only a label.
    assert_equal [ scenes(:scene_two) ], apply(filter_for(section_id: sections(:section_two).id.to_s))
    assert_equal [ scenes(:scene_three) ], apply(filter_for(section_id: SceneFilter::UNGROUPED))
  end

  test "a section filter that is not part of this story is dropped and reported" do
    other = filter_for(section_id: sections(:section_alt).id.to_s)

    assert_not other.active?
    assert_equal 1, other.discarded.size
    assert_match(/not a section of this story/, other.discarded.first)
    assert_equal @story.scenes.reorder(:position, :id).to_a, apply(other)
  end

  test "a scene tag filter uses the story's own tags only" do
    assert_equal [ scenes(:scene_one) ], apply(filter_for(scene_tag_id: scene_tags(:scene_tag_one).id.to_s))
    assert_equal [ scenes(:scene_one) ], apply(filter_for(scene_tag_id: scene_tags(:scene_tag_two).id.to_s))

    foreign = filter_for(scene_tag_id: scene_tags(:scene_tag_three).id.to_s)
    assert_not foreign.active?
    assert_match(/not a scene tag of this story/, foreign.discarded.first)
    assert_equal @story.scenes.reorder(:position, :id).to_a, apply(foreign)
  end

  test "the in-world range covers whole days inclusively and skips scenes without a time" do
    scenes(:scene_three).update!(datetime: Time.utc(2026, 10, 2, 10))

    assert_equal [ scenes(:scene_one) ], apply(filter_for(to: "2026-09-11"))
    assert_equal [ scenes(:scene_three) ], apply(filter_for(from: "2026-10-01"))
    assert_equal [ scenes(:scene_one), scenes(:scene_three) ],
      apply(filter_for(from: "2026-01-01", to: "2026-12-31"))
    # Both bounds are days: a scene earlier in the day is still in the range, and
    # the scene with no in-world time never is.
    assert_equal [ scenes(:scene_one) ], apply(filter_for(from: "2026-09-11", to: "2026-09-11"))
    assert_empty apply(filter_for(from: "2026-09-12", to: "2026-10-01"))
  end

  test "an unreadable in-world date is dropped and reported instead of guessing" do
    broken = filter_for(from: "not-a-date", to: "2026-09-11")

    assert_equal [ scenes(:scene_one), scenes(:scene_three) ], apply(broken)
    assert_equal 1, broken.discarded.size
    assert_match(/could not be read/, broken.discarded.first)
    assert_equal({ to: "2026-09-11" }, broken.query_params)
  end

  test "an end before the start matches nothing instead of being swapped" do
    assert_empty apply(filter_for(from: "2026-09-12", to: "2026-09-11"))
  end

  test "filters combine and the result stays in narrative order" do
    @story.scenes.create!(name: "A later secret", position: 3)
    @story.scenes.create!(name: "An earlier secret", position: 4)

    filtered = apply(filter_for(q: "secret", section_id: SceneFilter::UNGROUPED))
    assert_equal [ "A later secret", "An earlier secret" ], filtered.map(&:name)
  end

  test "query_params carries only the filters that are really in effect" do
    assert_equal({ q: "second" }, filter_for(q: "  second  ").query_params)
    assert_equal({ section_id: SceneFilter::UNGROUPED, from: "2026-09-01", to: "2026-09-30" },
      filter_for(section_id: SceneFilter::UNGROUPED, from: "2026-09-01", to: "2026-09-30").query_params)
  end

  private
    def filter_for(**params)
      SceneFilter.new(params, section_ids: @section_ids, scene_tags: @scene_tags)
    end

    def apply(filter)
      filter.apply(@story.scenes).to_a
    end

    def section_ids
      @section_ids ||= SectionPaths.build(@story.sections.reorder(:position, :id).to_a).ids
    end
end
