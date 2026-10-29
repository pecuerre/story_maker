require "test_helper"
require "fileutils"
require "tmpdir"

class StoryInterchangeTest < ActiveSupport::TestCase
  FIXTURE = Rails.root.join("test/fixtures/files/story_interchange/synthetic-universe")

  setup do
    @temporary_directory = Dir.mktmpdir("story-interchange-test")
    @root = File.join(@temporary_directory, "synthetic-universe")
    FileUtils.cp_r(FIXTURE, @root)
  end

  teardown do
    FileUtils.remove_entry(@temporary_directory) if File.directory?(@temporary_directory)
  end

  test "accepts the synthetic source and reports its identity and counts" do
    report = validate

    assert report.valid?, report.errors.map(&:to_s).join("\n")
    assert_empty report.warnings

    assert_equal "synthetic-universe", report.universe_slug
    assert_equal "Synthetic Universe", report.universe_name
    assert_equal [ { slug: "synthetic-story", name: "Synthetic Story" } ], report.stories

    assert_equal 3, report.counts[:canon_rules]
    assert_equal 1, report.counts[:canon_questions]
    assert_equal %w[K1 L1 D1], report.canon_rules.map(&:id)
    assert_equal "The lantern burns only while someone holds it.", report.canon_rules.second.statement
    assert_includes report.canon_rules.first.source, "- **K1.** The lantern was built before the first winter."
    assert_includes report.canon_rules.first.source, "Canon: universe/canon/mechanism.md"
    assert_equal [ "O-I1" ], report.canon_questions.map(&:id)
    assert_equal "Who built the first lantern?", report.canon_questions.first.statement
    assert_nil report.canon_questions.first.source
    assert_equal 1, report.counts[:characters]
    assert_equal 1, report.counts[:factions]
    assert_equal 1, report.counts[:locations]
    assert_equal 1, report.counts[:items]
    assert_equal 1, report.counts[:stories]
    assert_equal 1, report.counts[:plots]
    assert_equal 2, report.counts[:chapters]
    assert_equal 2, report.counts[:scenes]

    character = report.entity("ada")
    assert_equal :character, character.kind
    assert_equal "Ada", character.name
    assert_nil character.story_slug
    assert_equal "The engineer trusted by [[wardens]] to keep the lantern lit.",
      character.sections.find { |section| section.heading == "At a glance" }.body
    assert_empty character.introduction

    faction = report.entity("wardens")
    assert_equal :faction, faction.kind
    assert_equal "The Wardens", faction.name
    assert_equal "[[keep]]", faction.frontmatter["home"]

    # A Plot is parsed like an entity, and the story directory that holds it is
    # what scopes it.
    plot = report.entity("the-lantern")
    assert_equal :plot, plot.kind
    assert_equal "The lantern", plot.name
    assert_equal "synthetic-story", plot.story_slug
    assert_equal "The question",
      plot.sections.find { |section| section.heading == "The question" }.heading

    # Chapters are directories, so the report carries the Story and the
    # directory name rather than a file entity.
    assert_equal [
      StoryInterchange::Report::Chapter.new(story_slug: "synthetic-story", slug: "01-arrival"),
      StoryInterchange::Report::Chapter.new(story_slug: "synthetic-story", slug: "02-winter")
    ], report.chapters

    # A Scene is parsed like an entity too; its chapter is in its frontmatter
    # and its body is the manuscript prose.
    scene = report.entity("01-the-gate")
    assert_equal :scene, scene.kind
    assert_equal "The gate", scene.name
    assert_equal "synthetic-story", scene.story_slug
    assert_equal "01-arrival", scene.frontmatter["chapter"]
    assert_includes scene.introduction, "Ada carries the lantern through the gate"
  end

  test "reads the body before the first section as an introduction" do
    replace("universe/characters/ada.md", "# Ada\n", "# Ada\n\nAn engineer from the lower yard.\n")

    report = validate

    assert_equal "An engineer from the lower yard.", report.entity("ada").introduction
  end

  test "ignores references inside fenced blocks" do
    report = validate

    refute report.errors.any? { |issue| issue.message.include?("not-a-record") },
      "the README's fenced example must not be treated as a reference"
  end

  test "checks references written inside inline code" do
    replace("universe/characters/ada.md", "## At a glance", "## At a glance\n\nSee `[[nobody]]`.")

    report = validate

    assert_not report.valid?
    assert_match(/unknown record slug `nobody`/, errors(report))
  end

  test "reads the universe identity from the source directory name" do
    renamed = File.join(@temporary_directory, "the-fifth-cabinet")
    FileUtils.mv(@root, renamed)

    report = StoryInterchange.validate(renamed)

    assert report.valid?, report.errors.map(&:to_s).join("\n")
    assert_equal "the-fifth-cabinet", report.universe_slug
    assert_equal "The Fifth Cabinet", report.universe_name
  end

  test "parameterizes a source directory name into the universe slug" do
    renamed = File.join(@temporary_directory, "The Fifth Cabinet.git")
    FileUtils.mv(@root, renamed)

    report = StoryInterchange.validate(renamed)

    assert report.valid?, report.errors.map(&:to_s).join("\n")
    assert_equal "the-fifth-cabinet", report.universe_slug
    assert_equal "The Fifth Cabinet", report.universe_name
  end

  test "refuses a source directory name with no letters or digits" do
    renamed = File.join(@temporary_directory, "---")
    FileUtils.mv(@root, renamed)

    report = StoryInterchange.validate(renamed)

    assert_not report.valid?
    assert_match(/source directory name must contain a letter or digit/, errors(report))
  end

  test "reports a missing source directory" do
    report = StoryInterchange.validate(File.join(@temporary_directory, "missing"))

    assert_not report.valid?
    assert_match(/source directory does not exist/, errors(report))
  end

  test "requires YAML frontmatter on an entity file" do
    overwrite("universe/characters/ada.md", "# Ada\n\nNo frontmatter here.\n")

    report = validate

    assert_not report.valid?
    assert_match(/character: missing YAML frontmatter/, errors(report))
  end

  test "requires every kind-specific frontmatter key" do
    replace("universe/characters/ada.md", "role: \"engineer — the one who carries the lantern\"\n", "")

    report = validate

    assert_not report.valid?
    assert_match(/missing required frontmatter key `role`/, errors(report))
  end

  test "requires a slug to match its filename" do
    replace("universe/characters/ada.md", "slug: ada", "slug: ada-two")

    report = validate

    assert_not report.valid?
    assert_match(/slug `ada-two` must match the filename `ada.md`/, errors(report))
  end

  test "requires slugs to be unique across record kinds" do
    write("universe/locations/ada.md", <<~MARKDOWN)
      ---
      name: Another Ada
      slug: ada
      type: "installation"
      controller: "[[wardens]]"
      status: active
      ---

      # Another Ada
    MARKDOWN

    report = validate

    assert_not report.valid?
    assert_match(/duplicate record slug `ada`/, errors(report))
  end

  test "warns about an unknown frontmatter key without refusing the source" do
    replace("universe/characters/ada.md", "first_appears: B-001", "first_appears: B-001\nmood: calm")

    report = validate

    assert report.valid?, errors(report)
    assert_match(/unknown frontmatter key `mood`/, warnings(report))
  end

  test "reports a slug reference that names no record" do
    replace("universe/characters/ada.md", "affiliation: \"[[wardens]]\"", "affiliation: \"[[nobody]]\"")

    report = validate

    assert_not report.valid?
    assert_match(/unknown record slug `nobody`/, errors(report))
  end

  test "reports a rule reference that names no canon id" do
    replace("stories/synthetic-story/chapters/01-arrival/01-the-gate.md", "[[rule:L1]]", "[[rule:K99]]")

    report = validate

    assert_not report.valid?
    assert_match(/unknown canon rule `K99`/, errors(report))
  end

  test "reports an unknown reference form" do
    replace("universe/characters/ada.md", "## At a glance", "## At a glance\n\nSee [[thing:value]].")

    report = validate

    assert_not report.valid?
    assert_match(/unknown reference form `\[\[thing:value\]\]`/, errors(report))
  end

  test "requires canon ids to be unique" do
    replace("universe/canon/mechanism.md", "- **L1 — Light.** The lantern burns only while someone holds it.",
      "- **L1 — Light.** The lantern burns only while someone holds it.\n- **L1.** A duplicate.")

    report = validate

    assert_not report.valid?
    assert_match(/canon id L1 is already defined/, errors(report))
  end

  test "requires the canon ledger README" do
    FileUtils.rm(File.join(@root, "universe/canon/README.md"))

    report = validate

    assert_not report.valid?
    assert_match(%r{universe/canon/README\.md is required}, errors(report))
  end

  test "requires a scene dependency list to hold backlog ids" do
    replace("stories/synthetic-story/chapters/01-arrival/01-the-gate.md", "depends_on: [B-001]", "depends_on: B-001")

    report = validate

    assert_not report.valid?
    assert_match(/depends_on must be a list of B-### ids/, errors(report))
  end

  test "requires a scene sequence to match its filename prefix" do
    replace("stories/synthetic-story/chapters/01-arrival/01-the-gate.md", "sequence: 1", "sequence: 3")

    report = validate

    assert_not report.valid?
    assert_match(/scene sequence `3` must match filename prefix `01`/, errors(report))
  end

  test "requires a scene branch to be main or a named fork" do
    replace("stories/synthetic-story/chapters/01-arrival/01-the-gate.md", "branch: main", "branch: sideways")

    report = validate

    assert_not report.valid?
    assert_match(/scene branch `sideways`/, errors(report))
  end

  test "requires a scene point of view to name a character" do
    replace("stories/synthetic-story/chapters/01-arrival/01-the-gate.md", "pov: ada", "pov: nobody")

    report = validate

    assert_not report.valid?
    assert_match(/scene point of view `nobody` does not name a record/, errors(report))
  end

  test "requires a scene location to name a location" do
    replace("stories/synthetic-story/chapters/01-arrival/01-the-gate.md", "location: keep", "location: nowhere")

    report = validate

    assert_not report.valid?
    assert_match(/scene location `nowhere` does not name a record/, errors(report))
  end

  test "requires a scene status from the fixed vocabulary" do
    replace("stories/synthetic-story/chapters/01-arrival/01-the-gate.md", "status: draft", "status: polished")

    report = validate

    assert_not report.valid?
    assert_match(/scene status `polished`/, errors(report))
  end

  private
    def validate
      StoryInterchange.validate(@root)
    end

    def overwrite(relative_path, content)
      write(relative_path, content)
    end

    def write(relative_path, content)
      path = File.join(@root, relative_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end

    def replace(relative_path, before, after)
      path = File.join(@root, relative_path)
      content = File.read(path)
      assert_includes content, before, "the fixture no longer contains #{before.inspect}"
      File.write(path, content.sub(before, after))
    end

    def errors(report)
      report.errors.map(&:to_s).join("\n")
    end

    def warnings(report)
      report.warnings.map(&:to_s).join("\n")
    end
end
