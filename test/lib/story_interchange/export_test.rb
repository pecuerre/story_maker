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

  test "a story whose sections interleave keeps its narrative order on a round trip" do
    # Its narrative order is scene one, scene three, scene two, while the
    # chapter directories group them as section one, section two, ungrouped.
    scenes(:scene_two).update_columns(position: 2)
    scenes(:scene_three).update_columns(position: 1)

    export = StoryInterchange::Export.new(@universe)
    root = write(export)
    report = StoryInterchange.validate(root)

    assert report.valid?, report.errors.map(&:to_s).join("\n")
    assert_equal 0, report.entity("scene-one").frontmatter["position"]
    assert_equal 1, report.entity("scene-three").frontmatter["position"]
    assert_equal 2, report.entity("scene-two").frontmatter["position"]

    universe = StoryInterchange::Import.new(root, owner: users(:user_one)).call.universe
    story = universe.stories.find_by!(slug: "story-one")

    assert_equal %w[scene-one scene-three scene-two], story.scenes.order(:position, :id).pluck(:slug)
    assert_equal [ 0, 1, 2 ], story.scenes.order(:position, :id).pluck(:position)
  end

  test "a slug shared across two kinds is made unique and every reference follows it" do
    character = characters(:character_one)
    location = locations(:location_one)
    location.update!(slug: character.slug)
    character.update!(
      description: "Lives at [[location:#{location.slug}]].",
      summary: "The keeper of [[location:#{location.slug}]]."
    )
    canon_rules(:canon_rule_one).update!(statement: "Magic works at [[location:#{location.slug}]].")

    files = StoryInterchange::Export.new(@universe).files

    assert files.key?("one/universe/characters/character-one.md")
    assert files.key?("one/universe/locations/character-one-location.md")
    assert_includes files.fetch("one/universe/characters/character-one.md"), "Lives at [[location:character-one-location]]."
    assert_includes files.fetch("one/universe/characters/character-one.md"), "The keeper of [[location:character-one-location]]."
    assert_includes file(files, "/canon/magic.md"), "Magic works at [[location:character-one-location]]."

    report = StoryInterchange.validate(write(StoryInterchange::Export.new(@universe)))
    assert report.valid?, report.errors.map { |error| "#{error.path}: #{error.message}" }.join("\n")
  end

  test "a plot whose slug belongs to a record is renamed and the scene names the new slug" do
    locations(:location_one).update!(slug: "plot-one")

    files = StoryInterchange::Export.new(@universe).files

    assert files.key?("one/universe/locations/plot-one.md")
    assert files.key?("one/stories/story-one/plots/plot-one-plot.md")
    assert_includes file(files, "/01-scene-one.md"), "plot: plot-one-plot"

    report = StoryInterchange.validate(write(StoryInterchange::Export.new(@universe)))
    assert report.valid?, report.errors.map { |error| "#{error.path}: #{error.message}" }.join("\n")
  end

  test "two records of the same kind may share a slug in the app without losing one file" do
    character = characters(:character_one)
    characters(:character_two).update!(slug: character.slug)

    files = StoryInterchange::Export.new(@universe).files
    exported = files.keys.grep(%r{\Aone/universe/characters/.+\.md\z})

    assert_equal 3, exported.size
    assert_includes exported, "one/universe/characters/character-one.md"
    assert_includes exported, "one/universe/characters/character-one-character.md"

    report = StoryInterchange.validate(write(StoryInterchange::Export.new(@universe)))
    assert report.valid?, report.errors.map { |error| "#{error.path}: #{error.message}" }.join("\n")
  end

  test "two scenes in one story may share a slug in the app without a duplicate address" do
    scenes(:scene_two).update!(slug: scenes(:scene_one).slug)

    files = StoryInterchange::Export.new(@universe).files

    assert file(files, "/01-scene-one.md")
    assert file(files, "/01-scene-one-scene.md")

    report = StoryInterchange.validate(write(StoryInterchange::Export.new(@universe)))
    assert report.valid?, report.errors.map { |error| "#{error.path}: #{error.message}" }.join("\n")

    universe = StoryInterchange::Import.new(write(StoryInterchange::Export.new(@universe)),
      owner: users(:user_one)).call.universe
    story = universe.stories.find_by!(slug: "story-one")

    assert_equal %w[scene-one scene-one-scene scene-three], story.scenes.order(:position, :id).pluck(:slug)
  end

  test "a scene's drafting contract travels as the closing comment the reader keeps" do
    scenes(:scene_one).update!(drafting_contract: "- one place, one beat of time: can the lantern cross?\n" \
      "- exit question: who opened the gate?")

    files = StoryInterchange::Export.new(@universe).files
    scene = file(files, "/01-scene-one.md")

    assert_match(/<!--\nDRAFTING CONTRACT\n- one place, one beat of time: can the lantern cross\?\n- exit question: who opened the gate\?\n-->\n\z/, scene)

    root = write(StoryInterchange::Export.new(@universe))
    report = StoryInterchange.validate(root)

    assert report.valid?, report.errors.map { |error| "#{error.path}: #{error.message}" }.join("\n")
    assert_equal scenes(:scene_one).drafting_contract, report.entity("scene-one").drafting_contract

    universe = StoryInterchange::Import.new(root, owner: users(:user_one)).call.universe
    assert_equal scenes(:scene_one).drafting_contract,
      universe.scenes.find_by!(slug: "scene-one").drafting_contract
  end

  test "a scene with no drafting contract writes no closing comment" do
    files = StoryInterchange::Export.new(@universe).files

    assert_not_includes file(files, "/01-scene-one.md"), "DRAFTING CONTRACT"
  end

  test "a drafting contract reference follows a renamed record like prose does" do
    location = locations(:location_one)
    location.update!(slug: characters(:character_one).slug)
    scenes(:scene_one).update!(drafting_contract: "- one place: [[location:#{characters(:character_one).slug}]]")

    files = StoryInterchange::Export.new(@universe).files
    scene = file(files, "/01-scene-one.md")

    assert_includes scene, "- one place: [[location:character-one-location]]"
  end

  test "a drafting contract the comment would end early refuses the archive and names the scene" do
    scenes(:scene_one).update!(drafting_contract: "- one place.\n- one beat. --> the rest")

    error = assert_raises(StoryInterchange::Export::Unrepresentable) do
      StoryInterchange::Export.new(@universe).files
    end

    problem = error.problems.first
    assert_equal :contract, problem.reason
    assert_equal "Scene one", problem.scene
    assert_equal "- one beat. --> the rest", problem.text
    assert_equal 2, problem.line
  end

  test "narration the block grammar would split refuses the archive and names the scene" do
    scene_elements(:narration_one).update!(body: "An opening line.\n## A heading\nA closing line.")

    error = assert_raises(StoryInterchange::Export::Unrepresentable) do
      StoryInterchange::Export.new(@universe).files
    end

    problem = error.problems.first
    assert_equal :heading, problem.reason
    assert_equal "Scene one", problem.scene
    assert_equal "## A heading", problem.text
    assert_equal 2, problem.line
  end

  test "prose the reader would treat as a drafting note refuses the archive" do
    scene_elements(:narration_one).update!(body: "An opening line.\nA note <!-- hidden --> here.")

    error = assert_raises(StoryInterchange::Export::Unrepresentable) do
      StoryInterchange::Export.new(@universe).files
    end

    assert_equal :comment, error.problems.first.reason
    assert_includes error.problems.first.text, "<!-- hidden -->"
  end

  test "a dialogue turn containing a comment opener refuses the archive too" do
    scene_dialogue_turns(:turn_one).update!(body: "Count with me. <!-- aside -->")

    error = assert_raises(StoryInterchange::Export::Unrepresentable) do
      StoryInterchange::Export.new(@universe).files
    end

    assert_equal :comment, error.problems.first.reason
    assert_equal "Scene one", error.problems.first.scene
  end

  test "every scene whose narration would be split is named in one refusal" do
    scene_elements(:narration_one).update!(body: "Opening.\n## One heading")
    SceneElement.create!(scene: scenes(:scene_two), kind: SceneElement::NARRATION,
      name: "The second warning", body: "Opening.\n## Another heading")

    error = assert_raises(StoryInterchange::Export::Unrepresentable) do
      StoryInterchange::Export.new(@universe).files
    end

    assert_equal [ "Scene one", "Scene two" ].sort, error.problems.map(&:scene).sort
  end

  test "a narration subheading that is not a block heading survives the round trip" do
    scene_elements(:narration_one).update!(body: "Opening.\n### A smaller heading\n\nClosing.")

    root = write(StoryInterchange::Export.new(@universe))
    report = StoryInterchange.validate(root)

    assert report.valid?, report.errors.map { |error| "#{error.path}: #{error.message}" }.join("\n")

    universe = StoryInterchange::Import.new(root, owner: users(:user_one)).call.universe
    narration = universe.scenes.find_by!(slug: "scene-one").scene_elements
      .where(kind: SceneElement::NARRATION).order(:position).first

    assert_includes narration.body, "### A smaller heading"
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
