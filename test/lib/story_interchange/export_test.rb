require "test_helper"
require "fileutils"
require "tmpdir"

# The export writes a story-interchange source the validator accepts, and that
# source imports back as the same Universe. The directory is the contract; the
# archive only packs it.
class StoryInterchangeExportTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @temporary_directory = Dir.mktmpdir("story-interchange-export-test")
  end

  teardown do
    FileUtils.remove_entry(@temporary_directory) if File.directory?(@temporary_directory)
  end

  test "writes a directory the validator accepts under the universe slug" do
    root = write(StoryInterchange::Export.new(@universe))
    report = StoryInterchange.validate(root)

    assert report.valid?, report.errors.map { |error| "#{error.path}: #{error.message}" }.join("\n")
    assert_equal @universe.slug, report.universe_slug
    assert_equal @universe.name, report.universe_name
  end

  test "writes one file per record the interchange can describe" do
    files = StoryInterchange::Export.new(@universe).files

    assert files.key?("one/universe/characters/character-one.md")
    assert files.key?("one/universe/factions/faction-one.md")
    assert files.key?("one/universe/locations/location-one.md")
    assert files.key?("one/universe/tech/item-one.md")
    assert files.key?("one/universe/canon/magic.md")
    assert files.key?("one/universe/canon/rules.md")
    assert files.key?("one/stories/story-one/README.md")
    assert file(files, "/01-scene-one.md")
    assert file_matching(files, %r{/\d{2}-section-one/README\.md\z})
    assert files.key?("one/stories/story-one/plots/plot-one.md")
  end

  test "a scene alternates narration and dialog blocks and names its speakers" do
    files = StoryInterchange::Export.new(@universe).files
    scene = file(files, "/01-scene-one.md")

    assert_match(/\A---\n/, scene)
    assert_includes scene, "# Scene one"
    assert_includes scene, "## Narration"
    assert_includes scene, "## Dialog"
    assert_includes scene, '@[[character:character-three]] "Count with me."'
    assert_includes scene, '@[[character:character-one]] "One, two, three. Again, and slower this time."'
  end

  test "a scene with no prose still carries the narration block the validator requires" do
    files = StoryInterchange::Export.new(@universe).files
    scene = file(files, "/01-scene-two.md")

    assert_includes scene, "## Narration"
  end

  test "an ungrouped scene gets its own chapter so it is not lost" do
    files = StoryInterchange::Export.new(@universe).files
    readme_path = files.keys.find { |path| path.match?(%r{/\d{2}-ungrouped/README\.md\z}) }

    assert file(files, "/01-scene-three.md")
    assert readme_path, "expected an ungrouped chapter"
    assert_includes files.fetch(readme_path), "title: Ungrouped"
  end

  test "a character description is written before the summary so it survives the round trip" do
    character = characters(:character_one)
    character.update!(description: "An opening line.\n\n## History\n\nA life.", summary: "One line.")

    files = StoryInterchange::Export.new(@universe).files
    document = files.fetch("one/universe/characters/character-one.md")

    assert_operator document.index("An opening line."), :<, document.index("## Short summary")
    assert_includes document, "## History\n\nA life."
  end

  test "the exported source imports back as the same universe" do
    root = write(StoryInterchange::Export.new(@universe))

    result = StoryInterchange::Import.new(root, owner: users(:user_one)).call
    universe = result.universe

    assert_equal "one", universe.slug
    assert_equal "Universe one", universe.name
    assert_equal %w[character-one character-three character-two], universe.characters.order(:slug).pluck(:slug)
    assert_equal %w[faction-one faction-two], universe.factions.order(:slug).pluck(:slug)
    assert_equal %w[item-one item-two], universe.items.order(:slug).pluck(:slug)
    assert_equal %w[location-one location-two], universe.locations.order(:slug).pluck(:slug)

    assert_equal %w[spin-off story-one].sort, universe.stories.order(:slug).pluck(:slug).sort

    scene = universe.scenes.find_by!(slug: "scene-one")
    assert_equal "Scene one", scene.name
    assert scene.scene_elements.exists?(kind: SceneElement::DIALOGUE)
    assert_equal "Count with me.", scene.scene_elements
      .find_by!(kind: SceneElement::DIALOGUE).scene_dialogue_turns.order(:position).first.body
  end

  test "the archive is one gzip holding the directory" do
    export = StoryInterchange::Export.new(@universe)
    gzip = export.to_s.b

    assert gzip.start_with?("\x1F\x8B".b)
    assert_match(/\Aone-story-interchange-\d{8}-\d{6}\.tar\.gz\z/, export.filename)
  end

  private
    def file(files, suffix)
      path = files.keys.find { |candidate| candidate.end_with?(suffix) }
      assert path, "expected a file ending with #{suffix}"
      files.fetch(path)
    end

    def file_matching(files, pattern)
      path = files.keys.find { |candidate| candidate.match?(pattern) }
      assert path, "expected a file matching #{pattern.source}"
      files.fetch(path)
    end

    def write(export)
      root = File.join(@temporary_directory, @universe.slug)

      export.files.each do |path, content|
        full_path = File.join(@temporary_directory, path)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, content)
      end

      root
    end
end
