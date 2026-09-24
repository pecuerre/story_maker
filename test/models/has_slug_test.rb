require "test_helper"

class HasSlugTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
  end

  test "regenerates a slug when a name changes" do
    story = Story.create!(universe: @universe, name: "Original name")

    story.update!(name: "Renamed story")

    assert_equal "renamed-story", story.slug
  end

  test "preserves the slug when an unrelated attribute changes" do
    story = Story.create!(universe: @universe, name: "Stable story")

    story.update!(description: "Updated description")

    assert_equal "stable-story", story.slug
  end

  test "uses an explicitly supplied slug for the current save" do
    story = Story.create!(universe: @universe, name: "Original name", slug: "custom_slug")

    assert_equal "custom-slug", story.slug

    story.update!(slug: "replacement_slug")

    assert_equal "replacement-slug", story.slug

    story.update!(name: "Renamed story")

    assert_equal "renamed-story", story.slug
  end

  test "falls back safely when a name cannot be slugified" do
    story = Story.create!(universe: @universe, name: "!!!")

    assert_match(/\A[0-9a-f]{8}\z/, story.slug)
  end
end
