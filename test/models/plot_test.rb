require "test_helper"

class PlotTest < ActiveSupport::TestCase
  test "a Plot links multiple same-Story Scenes without changing their grouping or order" do
    plot = plots(:plot_one)

    assert_equal [ scenes(:scene_one), scenes(:scene_two) ], plot.scenes.order(:position, :id).to_a
    assert_equal [ plot ], scenes(:scene_one).plots.to_a
    assert_equal sections(:section_one), scenes(:scene_one).section
    assert_equal sections(:section_two), scenes(:scene_two).section
    assert_equal [ 0, 1 ], [ scenes(:scene_one).position, scenes(:scene_two).position ]
  end

  test "a Plot refuses an unknown, duplicate, or cross-Story Scene assignment" do
    plot = plots(:plot_one)
    foreign_scene = scenes(:scene_alt)

    plot.scene_ids = [ scenes(:scene_one).id, foreign_scene.id ]
    assert_not plot.valid?
    assert_includes plot.errors[:scenes], I18n.t("plots.errors.scene_must_belong_to_story")

    plot.scene_ids = [ scenes(:scene_one).id, scenes(:scene_one).id ]
    assert_not plot.valid?
    assert_includes plot.errors[:scenes], I18n.t("plots.errors.scene_must_be_unique")

    plot.scene_ids = [ -1 ]
    assert_not plot.valid?
    assert_includes plot.errors[:scenes], I18n.t("plots.errors.scene_must_exist")
  end

  test "a Scene refuses a Plot from another Story" do
    scene = scenes(:scene_one)
    scene.plot_ids = [ plots(:plot_alt).id ]

    assert_not scene.valid?
    assert_includes scene.errors[:plots], I18n.t("scenes.errors.plot_must_belong_to_story")
  end

  test "soft deleting and restoring a Plot preserves its Scene links" do
    plot = plots(:plot_one)
    scene_ids = plot.scene_ids

    plot.soft_delete
    assert_empty plot.class.where(id: plot.id)

    plot.restore
    assert_equal scene_ids.sort, plot.reload.scene_ids.sort
  end

  test "Plot names and slugs are unique among live records in a Story" do
    duplicate_name = stories(:story_one).plots.new(name: plots(:plot_one).name)
    assert_not duplicate_name.valid?
    assert_includes duplicate_name.errors[:name], "has already been taken"

    duplicate_slug = stories(:story_one).plots.new(name: "Different", slug: plots(:plot_one).slug)
    assert_not duplicate_slug.valid?
    assert_includes duplicate_slug.errors[:slug], "has already been taken"
  end
end
