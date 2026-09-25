require "test_helper"
require "fileutils"
require "tmpdir"

class UniverseDataLoaderTest < ActiveSupport::TestCase
  test "checks every registered development universe without writing records" do
    assert_no_difference -> { User.count + Universe.count + Story.count } do
      Development::UniverseDataRegistry::UNIVERSES.each_key do |universe|
        Development::UniverseDataLoader.new(universe: universe, environment: :test).check!
      end
    end
  end

  test "supports a schema-independent preflight for reset" do
    assert_nothing_raised do
      Development::UniverseDataLoader.check!(universe: "dark", validate_schema: false, environment: :test)
    end
  end

  test "loads the Dark universe and normalizes sibling positions" do
    assert_difference -> { Universe.where(slug: "dark").count }, 1 do
      Development::UniverseDataLoader.new(universe: "dark", environment: :development, verbose: false).load!
    end

    universe = Universe.find_by!(slug: "dark")
    story = universe.stories.first

    assert_equal "Dark", universe.name
    assert_equal "Netflix Dark", story.name
    assert_equal "netflix-dark", story.slug
    assert_equal 1, universe.stories.count
    assert_equal 15, story.sections.count
    assert_equal 4, story.scene_tags.count
    assert_equal 0, Universe.where(slug: "lotr").count
    assert_equal [ 0, 1, 2 ], story.sections.where(parent_id: nil).order(:position, :id).pluck(:position)
    assert_equal [ 0, 1, 2 ], story.section_tags.order(:position, :id).pluck(:position)
    assert_equal [ 0, 1 ], story.scene_tags.where(parent_id: nil).order(:position, :id).pluck(:position)
  end

  test "loads the Dark scenes as a contiguous flat narrative sequence" do
    Development::UniverseDataLoader.new(universe: "dark", environment: :development, verbose: false).load!

    story = Universe.find_by!(slug: "dark").stories.first
    scenes = story.scenes.reorder(:position, :id).to_a

    assert_equal 8, scenes.size
    assert_equal (0...8).to_a, scenes.map(&:position)
    assert_equal "Secrets", scenes.first.name
    assert_equal "The Golden Beast", scenes.last.name
    assert_equal [ "Mood", "Mystery" ], scenes.first.scene_tags.order(:position, :id).pluck(:name)
    assert_equal [ "Mystery" ], scenes[1].scene_tags.pluck(:name)
    assert_empty scenes[3].scene_tags

    assert_equal 1, scenes.count { |scene| scene.description.blank? }
    assert_equal [ "Double Lives" ], scenes.select { |scene| scene.description.blank? }.map(&:name)
    assert_equal 0, Universe.where(slug: "lotr").joins(:stories).sum { |universe| universe.scenes.count }
  end

  test "loads the LOTR scenes in narrative order" do
    Development::UniverseDataLoader.new(universe: "lotr", environment: :development, verbose: false).load!

    story = Universe.find_by!(slug: "lotr").stories.first

    assert_equal 5, story.scenes.count
    assert_equal [ 0, 1, 2, 3, 4 ], story.scenes.reorder(:position, :id).pluck(:position)
    assert_equal "A Long-expected Party", story.scenes.reorder(:position, :id).first.name
    assert_equal [ "Adventure", "Fellowship" ], story.scenes.first.scene_tags.order(:position, :id).pluck(:name)
  end

  test "loads the LOTR universe with stable converted slugs" do
    Development::UniverseDataLoader.new(universe: "lotr", environment: :development, verbose: false).load!

    universe = Universe.find_by!(slug: "lotr")
    story = universe.stories.first

    assert_equal "The Lord of the Rings", story.name
    assert_equal "the-lord-of-the-rings", story.slug
    assert_equal [ "the-fellowship-of-the-ring", "the-two-towers", "the-return-of-the-king" ], story.sections.order(:position, :id).pluck(:slug)
  end

  test "loads the LOTR world-building records with nested locations and a chained timeline" do
    Development::UniverseDataLoader.new(universe: "lotr", environment: :development, verbose: false).load!

    universe = Universe.find_by!(slug: "lotr")

    assert_equal 7, universe.characters.count
    assert_equal 12, universe.locations.count
    assert_equal 5, universe.items.count
    assert_equal 5, universe.relations.count
    assert_equal 5, universe.ownerships.count
    assert_equal 6, universe.events.count

    race = universe.character_tags.find_by!(name: "Race")
    hobbit = universe.character_tags.find_by!(name: "Hobbit")
    assert_equal race, hobbit.parent

    regions = universe.locations.where(name: %w[Eriador Rohan Gondor Mordor]).order(:position)
    assert_equal [ 0, 1, 2, 3 ], regions.pluck(:position)
    assert_equal "Mordor", universe.locations.find_by!(name: "Barad-dûr").parent.name

    ring = universe.ownerships.find_by!(slug: "frodo-one-ring")
    assert_equal universe.items.find_by!(name: "The One Ring"), ring.item
    assert_equal universe.characters.find_by!(name: "Frodo Baggins"), ring.character
    assert ring.from_date < ring.to_date

    leader_tag = universe.relation_tags.find_by!(name: "is leader of")
    assert_not leader_tag.symmetric?
    assert_equal "is led by", leader_tag.inverse

    timeline = universe.events.order(:position).to_a
    assert_equal "The Ring Is Given to Frodo", timeline.first.title
    timeline.each_cons(2) do |previous, event|
      assert_equal previous, event.after_event
    end
  end

  test "rejects loading outside the development environment" do
    error = assert_raises(Development::UniverseDataLoader::EnvironmentError) do
      Development::UniverseDataLoader.new(universe: "dark", environment: :production).load!
    end

    assert_match(/only be loaded in development/, error.message)
  end

  test "rejects unknown universes before touching the data directory" do
    error = assert_raises(Development::UniverseDataLoader::ValidationError) do
      Development::UniverseDataLoader.new(universe: "missing", environment: :test).check!
    end

    assert_match(/Unknown development universe/, error.message)
    assert_match(/dark, lotr/, error.message)
  end

  test "rejects missing symbolic references" do
    with_data_copy do |directory|
      characters_path = File.join(directory, "db/data/dark/characters.yml")
      contents = File.read(characters_path)
      File.write(characters_path, contents.sub("CharacterTag.family_kahnwald", "CharacterTag.missing"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/references missing CharacterTag\.missing/, error.message)
    end
  end

  test "rejects missing and unexpected model files" do
    with_data_copy do |directory|
      FileUtils.rm(File.join(directory, "db/data/dark/items.yml"))
      File.write(File.join(directory, "db/data/dark/extra.yml"), "[]\n")

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/missing: items\.yml/, error.message)
      assert_match(/unexpected: extra\.yml/, error.message)
    end
  end

  test "rejects raw foreign-key ids in association fields" do
    with_data_copy do |directory|
      characters_path = File.join(directory, "db/data/dark/characters.yml")
      contents = File.read(characters_path)
      File.write(characters_path, contents.sub("universe: Universe.dark", "universe: Universe.dark\n  universe_id: 1"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/use the association name instead of universe_id/, error.message)
    end
  end

  test "rejects non-string association values" do
    with_data_copy do |directory|
      universes_path = File.join(directory, "db/data/dark/universes.yml")
      contents = File.read(universes_path)
      File.write(universes_path, contents.sub("owner: User.dark_admin", "owner: 1"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/owner.*Model\.slug reference/, error.message)
    end
  end

  test "rejects scalar values for collection associations" do
    with_data_copy do |directory|
      characters_path = File.join(directory, "db/data/dark/characters.yml")
      contents = File.read(characters_path)
      File.write(characters_path, contents.sub("character_tags: [ CharacterTag.family_kahnwald, CharacterTag.sic_mundus ]", "character_tags: CharacterTag.family_kahnwald"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/character_tags.*array/, error.message)
    end
  end

  test "rejects references to the wrong association target class" do
    with_data_copy do |directory|
      ownerships_path = File.join(directory, "db/data/dark/ownerships.yml")
      contents = File.read(ownerships_path)
      File.write(ownerships_path, contents.sub("character: Character.jonas", "character: Item.jonas_key"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/must reference Character, not Item/, error.message)
    end
  end

  test "rejects a scene grouped under a section from another story" do
    with_data_copy do |directory|
      stories_path = File.join(directory, "db/data/dark/stories.yml")
      File.write(stories_path, "#{File.read(stories_path)}\n- universe: Universe.dark\n  name: Second story\n  slug: second-story\n")

      sections_path = File.join(directory, "db/data/dark/sections.yml")
      File.write(sections_path, "#{File.read(sections_path)}\n- story: Story.second-story\n  name: Elsewhere\n  slug: elsewhere\n")

      scenes_path = File.join(directory, "db/data/dark/scenes.yml")
      File.write(scenes_path, <<~YAML)
        - story: Story.netflix-dark
          name: Borrowed group
          slug: borrowed-group
          section: Section.elsewhere
          position: 0
      YAML

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/section must belong to the same story/, error.message)
    end
  end

  test "rejects a scene linked to an event from another universe" do
    with_data_copy do |directory|
      scenes_path = File.join(directory, "db/data/dark/scenes.yml")
      contents = File.read(scenes_path)
      File.write(scenes_path, contents.sub("event: Event.time_travel", "event: Event.ring_given_to_frodo"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/references missing Event\.ring_given_to_frodo/, error.message)
    end
  end

  test "rejects a scene tag from another story" do
    with_data_copy do |directory|
      stories_path = File.join(directory, "db/data/dark/stories.yml")
      File.write(stories_path, "#{File.read(stories_path)}\n- universe: Universe.dark\n  name: Second story\n  slug: second-story\n")

      scene_tags_path = File.join(directory, "db/data/dark/scene_tags.yml")
      File.write(scene_tags_path, "#{File.read(scene_tags_path)}\n- story: Story.second-story\n  name: Foreign scene tag\n  slug: foreign-scene-tag\n")

      scenes_path = File.join(directory, "db/data/dark/scenes.yml")
      contents = File.read(scenes_path)
      File.write(scenes_path, contents.sub("scene_tags: [ SceneTag.mood, SceneTag.mystery ]", "scene_tags: [ SceneTag.foreign-scene-tag ]"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/tag 'foreign-scene-tag' must belong to the same story/, error.message)
    end
  end

  test "loads Scene grouping and in-world references from the manifests" do
    Development::UniverseDataLoader.new(universe: "dark", environment: :development, verbose: false).load!

    story = Universe.find_by!(slug: "dark").stories.first
    scenes = story.scenes.reorder(:position, :id).to_a
    paths = SectionPaths.build(story.sections.reorder(:position, :id).to_a)

    assert_equal "Season 1 / Episode 1: Secrets", paths.label_for(scenes.first.section_id)
    assert_equal "Jonas meets Bartosz - 2024-01-01 10:00", scenes.first.event.display_string
    assert_equal Time.utc(1986, 9, 1, 10), scenes.first.datetime

    # A datetime without an event, an event without a datetime, and a shared event.
    assert_nil scenes[2].event
    assert_equal Time.utc(2019, 11, 5, 21), scenes[2].datetime
    assert_equal scenes[4].event, scenes[5].event

    # A title-only, ungrouped scene.
    assert_equal "Double Lives", scenes[3].name
    assert_nil scenes[3].section
    assert_nil scenes[3].event
    assert_nil scenes[3].datetime
  end

  test "rejects references to records outside the selected universe" do
    with_data_copy do |directory|
      sections_path = File.join(directory, "db/data/dark/sections.yml")
      contents = File.read(sections_path)
      File.write(sections_path, contents.sub("story: Story.netflix-dark", "story: Story.the-lord-of-the-rings"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/references missing Story\.the-lord-of-the-rings/, error.message)
    end
  end

  test "rolls back all records when a model validation fails late in the load" do
    with_data_copy do |directory|
      event_tags_path = File.join(directory, "db/data/dark/event_tags.yml")
      contents = File.read(event_tags_path)
      File.write(event_tags_path, contents.sub('bgcolor: "#3357FF"', 'bgcolor: "not-a-color"'))

      assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :development, verbose: false).load!
      end

      assert_not Universe.exists?(slug: "dark")
    end
  end

  test "refuses to load a universe that already exists" do
    user = User.create!(name: "Existing owner", email_address: "existing-owner@example.com", password: "password")
    Universe.create!(name: "Existing Dark", slug: "dark", owner: user, private: false)

    error = assert_raises(Development::UniverseDataLoader::ValidationError) do
      Development::UniverseDataLoader.new(universe: "dark", environment: :development, verbose: false).load!
    end

    assert_match(/already exists/, error.message)
  end

  private
    def with_data_copy
      Dir.mktmpdir("universe-data") do |directory|
        data_root = File.join(directory, "db/data")
        FileUtils.mkdir_p(data_root)
        FileUtils.cp_r(Rails.root.join("db/data/dark"), File.join(data_root, "dark"))
        FileUtils.cp_r(Rails.root.join("db/data/lotr"), File.join(data_root, "lotr"))
        yield directory
      end
    end
end
