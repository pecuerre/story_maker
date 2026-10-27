require "test_helper"

# A Scene's link to an Event is its own row, because a Scene may depict several
# Events, each with the author's own free-text role and its own order. These tests
# hold the link's rules in isolation from the editor and from the comparison that
# reads it.
class SceneEventTest < ActiveSupport::TestCase
  setup do
    @scene = scenes(:scene_one)
    @story = @scene.story
    @universe = @story.universe
  end

  test "a link carries its event, an optional role, and its order" do
    link = @scene.scene_events.create!(event: events(:event_two), role: "  climax  ", position: 1)

    assert_equal events(:event_two), link.event
    assert_equal "climax", link.role
    assert_equal 1, link.position
    assert_equal @universe, link.universe
  end

  test "a blank role is stored as no role" do
    link = @scene.scene_events.create!(event: events(:event_two), role: "   ")

    assert_nil link.role
  end

  test "a scene may depict several events while another scene depicts the same one" do
    @scene.scene_events.create!(event: events(:event_two))
    scenes(:scene_two).scene_events.create!(event: events(:event_one))

    assert_equal [ events(:event_one), events(:event_two) ], @scene.reload.events.to_a
    assert_equal [ scenes(:scene_one), scenes(:scene_two) ], events(:event_one).scenes.reorder(:position, :id).to_a
  end

  test "the same event cannot be linked to one scene twice" do
    duplicate = @scene.scene_events.new(event: events(:event_one))

    assert_not duplicate.valid?
    assert_equal [ I18n.t("scenes.events.already_linked") ], duplicate.errors[:event_id]
  end

  test "a removed link frees the pair for a new one" do
    existing = scene_events(:scene_event_one)
    existing.soft_delete

    replacement = @scene.scene_events.create!(event: events(:event_one))

    assert_predicate existing.reload, :deleted?
    assert_equal events(:event_one), replacement.event
  end

  test "an event from another universe is rejected" do
    link = @scene.scene_events.new(event: events(:event_other_universe))

    assert_not link.valid?
    assert_equal [ I18n.t("scenes.errors.must_belong_to_universe") ], link.errors[:event]
  end

  test "an unknown event is a field error instead of a foreign key exception" do
    link = @scene.scene_events.new(event_id: 999_999)

    assert_not link.valid?
    assert_equal [ I18n.t("scenes.errors.must_exist") ], link.errors[:event]
  end

  test "a missing event is rejected" do
    link = @scene.scene_events.new

    assert_not link.valid?
    assert link.errors[:event].any?
  end

  test "soft-deleting an event removes its links but keeps the scene" do
    link = scene_events(:scene_event_one)

    events(:event_one).soft_delete

    assert_predicate link.reload, :deleted?
    refute_predicate @scene.reload, :deleted?
    assert_empty @scene.events
  end

  test "soft-deleting a scene cascades its links" do
    link = scene_events(:scene_event_one)

    @scene.soft_delete

    assert_predicate link.reload, :deleted?
    assert Event.exists?(link.event_id)
  end

  test "names itself by the event it depicts" do
    assert_equal events(:event_one).display_label, scene_events(:scene_event_one).display_label
  end

  test "the link is read on the scene's events tab" do
    link = scene_events(:scene_event_one)
    expected = Rails.application.routes.url_helpers.universe_story_scene_scene_events_path(
      universe_slug: @universe.slug, story_id: @story.id, scene_id: @scene.id
    )

    assert_equal expected, link.search_url
  end
end
