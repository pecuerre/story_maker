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

    assert_equal 4, report.counts[:canon_rules]
    assert_equal 1, report.counts[:canon_questions]
    assert_equal %w[K1 L1 D1 O-I1], report.canon_rules.map(&:id)
    assert_equal %w[k1 l1 d1 o-i1], report.canon_rules.map(&:slug)
    assert_equal %w[locked rule consequence open], report.canon_rules.map(&:canon_type)
    assert_equal [ "The lantern was built before the first winter.", "Light",
      "A lantern left on the ground goes dark.", "Who built the first lantern?" ],
      report.canon_rules.map(&:name)
    assert_equal %w[mechanism mechanism mechanism mechanism], report.canon_rules.map(&:category)
    assert_equal "The lantern burns only while someone holds it.", report.canon_rules.second.statement
    assert_includes report.canon_rules.first.source, "K1. The lantern was built before the first winter."
    refute_includes report.canon_rules.first.source, "universe/canon/mechanism.md"
    assert_equal [ "O-I1" ], report.canon_questions.map(&:id)
    assert_equal "o-i1", report.canon_questions.first.slug
    assert_equal "open", report.canon_questions.first.canon_type
    assert_equal "mechanism", report.canon_questions.first.category
    assert_equal "Who built the first lantern?", report.canon_questions.first.statement
    assert_includes report.canon_questions.first.source, "Who built the first lantern?"
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
    assert_equal "The engineer trusted by [[faction:wardens]] to keep the lantern lit.",
      character.sections.find { |section| section.heading == "Short summary" }.body
    assert_empty character.introduction

    faction = report.entity("wardens")
    assert_equal :faction, faction.kind
    assert_equal "The Wardens", faction.name
    assert_equal "[[location:keep]]", faction.frontmatter["home"]

    # A Plot is parsed like an entity, and the story directory that holds it is
    # what scopes it.
    plot = report.entity("the-lantern")
    assert_equal :plot, plot.kind
    assert_equal "The lantern", plot.name
    assert_equal "synthetic-story", plot.story_slug
    assert_equal "The question",
      plot.sections.find { |section| section.heading == "The question" }.heading

    # Chapters are directories, so the report carries the Story, the directory
    # name, and the `#` heading its README supplies as the display name.
    assert_equal [
      StoryInterchange::Report::Chapter.new(story_slug: "synthetic-story", slug: "01-arrival", name: "The Arrival Gate"),
      StoryInterchange::Report::Chapter.new(story_slug: "synthetic-story", slug: "02-winter", name: "Winter")
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
    replace("universe/characters/ada.md", "## Short summary",
      "## Short summary\n\n```\n[[not-a-record]]\n```\n")

    report = validate

    refute report.errors.any? { |issue| issue.message.include?("not-a-record") },
      "a fenced example must not be treated as a reference"
  end

  test "does not read a README as a record or check its references" do
    report = validate

    assert report.valid?, report.errors.map(&:to_s).join("\n")
    assert_nil report.entity("README")
    assert_equal 1, report.counts[:characters]
    assert_equal 1, report.counts[:plots]
    assert_equal 2, report.counts[:scenes]
  end

  test "strips an HTML comment from stored prose and ignores its references" do
    replace("universe/characters/ada.md", "The engineer trusted by [[faction:wardens]] to keep the lantern lit.",
      "The engineer trusted by [[faction:wardens]] to keep the lantern lit.\n\n<!-- [[nobody]] drafting note -->")

    report = validate

    assert report.valid?, report.errors.map(&:to_s).join("\n")
    assert_equal "The engineer trusted by [[faction:wardens]] to keep the lantern lit.",
      report.entity("ada").sections.find { |section| section.heading == "Short summary" }.body
  end

  test "refuses a typed reference to a record of another kind" do
    replace("universe/characters/ada.md", "[[location:keep]]", "[[character:keep]]")

    report = validate

    assert_not report.valid?
    assert_match(/reference `\[\[character:keep\]\]` names a location, not a character/, errors(report))
  end

  test "refuses a typed reference to a missing record" do
    replace("universe/characters/ada.md", "[[faction:wardens]]", "[[faction:nobody]]")

    report = validate

    assert_not report.valid?
    assert_match(/unknown record slug `nobody`/, errors(report))
  end

  test "reads the universe display name from universe/README.md" do
    write("universe/README.md", "# Meridian\n\nThe shared universe.\n")

    report = validate

    assert report.valid?, report.errors.map(&:to_s).join("\n")
    assert_equal "synthetic-universe", report.universe_slug
    assert_equal "Meridian", report.universe_name
  end

  test "warns about an entry directly under universe/ that no slice reads" do
    write("universe/inspirations.md", "# Inspirations\n\nWhere the story comes from.\n")

    report = validate

    assert report.valid?, errors(report)
    assert_match(/unexpected entry in universe\//, warnings(report))
  end

  test "reads a scene title heading as the name, not as a section" do
    report = validate
    scene = report.entity("01-the-gate")

    assert_equal "The gate", scene.name
    assert_empty scene.sections
    assert_includes scene.introduction, "Ada carries the lantern through the gate"
  end

  test "checks references written inside inline code" do
    replace("universe/characters/ada.md", "## Short summary", "## Short summary\n\nSee `[[nobody]]`.")

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
    replace("universe/characters/ada.md", "affiliation: \"[[faction:wardens]]\"\n", "")

    report = validate

    assert_not report.valid?
    assert_match(/missing required frontmatter key `affiliation`/, errors(report))
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
    replace("universe/characters/ada.md", "affiliation: \"[[faction:wardens]]\"",
      "affiliation: \"[[faction:wardens]]\"\nmood: calm")

    report = validate

    assert report.valid?, errors(report)
    assert_match(/unknown frontmatter key `mood`/, warnings(report))
  end

  test "reports a slug reference that names no record" do
    replace("universe/characters/ada.md", "affiliation: \"[[faction:wardens]]\"",
      "affiliation: \"[[faction:nobody]]\"")

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

  test "accepts [[canon:ID]] as a canon reference" do
    replace("stories/synthetic-story/chapters/01-arrival/01-the-gate.md", "[[rule:L1]]", "[[canon:K1]]")

    report = validate

    assert report.valid?, errors(report)
  end

  test "reports a canon reference that names no canon id" do
    replace("stories/synthetic-story/chapters/01-arrival/01-the-gate.md", "[[rule:L1]]", "[[canon:K99]]")

    report = validate

    assert_not report.valid?
    assert_match(/unknown canon rule `K99`/, errors(report))
  end

  test "reports an unknown reference form" do
    replace("universe/characters/ada.md", "## Short summary", "## Short summary\n\nSee [[thing:value]].")

    report = validate

    assert_not report.valid?
    assert_match(/unknown reference form `\[\[thing:value\]\]`/, errors(report))
  end

  test "reads a canon item's title after any dash separator" do
    replace("universe/canon/mechanism.md", "- **L1 — Light.**", "- **L1 - Trigger.**")

    report = validate

    assert report.valid?, errors(report)
    assert_equal "Trigger", report.canon_rules.second.name
    assert_equal "l1", report.canon_rules.second.slug
    assert_equal "The lantern burns only while someone holds it.", report.canon_rules.second.statement
  end

  test "keeps the whole item as its statement and source" do
    replace("universe/canon/mechanism.md",
      "- **K1.** The lantern was built before the first winter.",
      "- **K1.** The lantern was built before the first winter, and the\n" \
      "  wall around it is younger.\n\n" \
      "  A second paragraph says the gate came later.")

    rule = validate.canon_rules.first

    assert_equal "The lantern was built before the first winter, and the wall around it is younger.",
      rule.statement
    assert_includes rule.source, "The lantern was built before the first winter, and the\nwall around it is younger."
    assert_includes rule.source, "A second paragraph says the gate came later."
  end

  test "strips markdown and source-file paths from a canon item" do
    replace("universe/canon/mechanism.md",
      "- **K1.** The lantern was built before the first winter.",
      "- **K1.** The **lantern** was built before the *first* winter, as " \
      "`universe/canon/mechanism.md` records.\n\n" \
      "  See the `README.md` for `code`.\n\n" \
      "  ~~Old wording.~~ The table below is a note.\n\n" \
      "  | Band | Meaning |\n  |---|:---:|\n  | 1 | now |\n\n" \
      "  - a bullet\n  - another")

    rule = validate.canon_rules.first

    assert_equal "The lantern was built before the first winter, as records.", rule.statement
    assert_includes rule.source, "The lantern was built before the first winter, as records."
    assert_includes rule.source, "See the for code."
    assert_includes rule.source, "Old wording. The table below is a note."
    assert_includes rule.source, "Band · Meaning"
    assert_includes rule.source, "1 · now"
    assert_includes rule.source, "a bullet\nanother"
    refute_includes rule.source, "**"
    refute_includes rule.source, "`"
    refute_includes rule.source, "|"
    refute_includes rule.source, "~~"
    refute_includes rule.source, "mechanism.md"
    refute_includes rule.source, "README.md"
  end

  test "removes a citation tail from a canon item's title and keeps it in the source" do
    replace("universe/canon/mechanism.md", "- **L1 — Light.**", "- **L1 — Light (Amended by K27).**")

    rule = validate.canon_rules.second

    assert_equal "Light", rule.name
    assert_includes rule.source, "(Amended by K27)"
  end

  test "skips a leading amendment note when it names an untitled item" do
    replace("universe/canon/mechanism.md",
      "- **K1.** The lantern was built before the first winter.",
      "- **K1.** *(Amended by K27.)* The lantern was built before the first winter.\n\n" \
      "  The note stays in the passage.")

    rule = validate.canon_rules.first

    assert_equal "The lantern was built before the first winter.", rule.name
    assert_equal "The lantern was built before the first winter.", rule.statement
    assert_includes rule.source, "(Amended by K27.) The lantern was built before the first winter."
  end

  test "names an untitled canon item after its own statement" do
    rule = validate.canon_rules.first

    assert_equal "K1", rule.id
    assert_equal "The lantern was built before the first winter.", rule.name
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
