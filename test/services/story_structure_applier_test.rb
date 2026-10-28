require "test_helper"

class StoryStructureApplierTest < ActiveSupport::TestCase
  setup do
    @story = universes(:universe_one).stories.create!(name: "Structure test story")
    @entry = StoryStructureCatalog.find("three-act")
  end

  test "creates the entry's acts as sections and beats as scenes in order" do
    assert StoryStructureApplier.call(@story, @entry)

    sections = @story.sections.order(:position, :id).to_a
    assert_equal @entry.acts.map { |act| I18n.t(act.name_key) }, sections.map(&:name)
    assert_equal (0...@entry.section_count).to_a, sections.map(&:position)

    scenes = @story.scenes.order(:position, :id).to_a
    assert_equal @entry.acts.flat_map { |act| act.beats.map { |beat| I18n.t(beat.name_key) } },
      scenes.map(&:name)
    assert_equal @entry.acts.flat_map { |act| act.beats.map { |beat| I18n.t(beat.description_key) } },
      scenes.map(&:description)
    assert_equal (0...@entry.scene_count).to_a, scenes.map(&:position)

    @entry.acts.each_with_index do |act, index|
      section = sections[index]
      assert_equal act.beats.map { |beat| I18n.t(beat.name_key) },
        section.scenes.order(:position, :id).map(&:name)
    end

    assert scenes.all? { |scene| scene.scene_elements.empty? },
      "a structure seeds names and guidance, never prose or Elements"
  end

  test "applies the labels in the request's language" do
    I18n.with_locale(:es) do
      assert StoryStructureApplier.call(@story, @entry)
    end

    assert_equal I18n.t(@entry.acts.first.name_key, locale: :es), @story.sections.order(:position).first.name
    assert_equal I18n.t(@entry.acts.first.beats.first.name_key, locale: :es),
      @story.scenes.order(:position).first.name
  end

  test "refuses a story that already has a section or a scene" do
    assert StoryStructureApplier.call(@story, @entry)

    assert_no_difference [ "Section.count", "Scene.count" ] do
      assert_not StoryStructureApplier.call(@story, @entry)
    end
  end

  test "treats a story with only removed sections and scenes as empty" do
    @story.sections.create!(name: "Removed act").soft_delete
    @story.scenes.create!(name: "Removed beat").soft_delete

    assert StoryStructureApplier.call(@story, @entry)

    assert_equal @entry.section_count, @story.sections.count
    assert_equal @entry.scene_count, @story.scenes.count
  end
end
