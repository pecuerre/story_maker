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
    assert_equal [ "The lantern built before the first winter", "Light burns only while someone holds the lantern",
      "A lantern left on the ground goes dark", "Who built the first lantern" ],
      report.canon_rules.map(&:name)
    assert_equal %w[mechanism mechanism mechanism mechanism], report.canon_rules.map(&:category)
    assert_equal "Light burns only while someone holds the lantern\n\nThe lantern burns only while someone holds it.",
      report.canon_rules.second.statement
    assert_nil report.canon_rules.first.source
    assert_equal [ "O-I1" ], report.canon_questions.map(&:id)
    assert_equal "o-i1", report.canon_questions.first.slug
    assert_equal "open", report.canon_questions.first.canon_type
    assert_equal "mechanism", report.canon_questions.first.category
    assert_equal "Who built the first lantern\n\nWho built the first lantern?",
      report.canon_questions.first.statement
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
    assert_equal "The engineer trusted by [[faction:wardens]] to keep the lantern lit.",
      character.sections.find { |section| section.heading == "Short summary" }.body
    assert_empty character.introduction

    faction = report.entity("wardens")
    assert_equal :faction, faction.kind
    assert_equal "The Wardens", faction.name
    assert_equal %w[name slug], faction.frontmatter.keys
    information = faction.sections.find { |section| section.heading == "Information" }
    assert_includes information.body, "- Home: [[location:keep]]"

    # A Plot is parsed like an entity, and the story directory that holds it is
    # what scopes it.
    plot = report.entity("the-lantern")
    assert_equal :plot, plot.kind
    assert_equal "The lantern", plot.name
    assert_equal "synthetic-story", plot.story_slug
    assert_equal %w[name slug], plot.frontmatter.keys
    assert_equal [ "Short summary", "Information", "The question", "Stakes", "Players", "Status",
      "Decisions taken (author)", "Progression", "Open questions", "Resolved" ],
      plot.sections.map(&:heading)

    # Chapters are directories, so the report carries the Story, the directory
    # name, and the `#` heading its README supplies as the display name.
    assert_equal [ "01-arrival", "02-winter" ], report.chapters.map(&:slug)
    assert_equal [ "synthetic-story", "synthetic-story" ], report.chapters.map(&:story_slug)
    assert_equal [ "The Arrival Gate", "Winter" ], report.chapters.map(&:name)

    # The README's prose before its first `##` is the Section description, and
    # the subsection has no Section column so the importer reports it.
    arrival = report.chapters.first
    assert_includes arrival.description, "[[location:keep]] and follows [[ada]]"
    assert_equal [ "What is here" ], arrival.sections.map(&:heading)
    assert_empty report.chapters.last.description

    # A Scene is parsed like an entity too; its chapter and sequence are the
    # path, so the report names the directory that holds it, and its body is the
    # alternating narration/dialog blocks.
    scene = report.entity("01-the-gate")
    assert_equal :scene, scene.kind
    assert_equal "The gate", scene.name
    assert_equal "synthetic-story", scene.story_slug
    assert_equal "01-arrival", scene.chapter_slug
    assert_equal %w[Narration Dialog], scene.sections.map(&:heading)
    # The closing drafting contract is a Scene fact with its own column, so it
    # is read rather than reported or left in the prose.
    assert_includes scene.drafting_contract, "one place, one beat of time"
    assert_empty scene.introduction
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
    assert_equal %w[Narration Dialog], scene.sections.map(&:heading)
    assert_includes scene.sections.first.body, "Ada carries the lantern through the gate"
  end

  test "keeps a scene's chapter and sequence in the path" do
    report = validate
    scene = report.entity("02-the-hall")

    assert_equal "01-arrival", scene.chapter_slug
    assert_equal "02-the-hall", scene.slug
    # The old frontmatter keys are not required and not read.
    assert_nil scene.frontmatter["chapter"]
    assert_nil scene.frontmatter["sequence"]
  end

  test "allows two scenes to share the backlog id the scene was written from" do
    replace("stories/synthetic-story/chapters/01-arrival/02-the-hall.md", "id: B-002", "id: B-001")

    report = validate

    assert report.valid?, errors(report)
    assert_equal [ "B-001", "B-001" ], report.entities(:scene).map { |scene| scene.frontmatter["id"] }
  end

  test "refuses a scene body that does not open with narration" do
    replace("stories/synthetic-story/chapters/01-arrival/01-the-gate.md", "## Narration", "## Dialog")

    report = validate

    assert_not report.valid?
    assert_match(/the first scene block must be `## Narration`/, errors(report))
  end

  test "refuses two scene blocks of the same kind in a row" do
    replace("stories/synthetic-story/chapters/01-arrival/01-the-gate.md", "## Dialog", "## Narration")

    report = validate

    assert_not report.valid?
    assert_match(/two `## Narration` blocks cannot sit next to each other/, errors(report))
  end

  test "refuses a scene section that is neither narration nor dialog" do
    replace("stories/synthetic-story/chapters/01-arrival/01-the-gate.md", "## Dialog", "## Notes")

    report = validate

    assert_not report.valid?
    assert_match(/scene section `Notes` is not a `## Narration` or `## Dialog` block/, errors(report))
  end

  test "refuses a dialog line without a speaker and a quoted line" do
    replace("stories/synthetic-story/chapters/01-arrival/01-the-gate.md",
      '@[[character:ada]] "The gate is open."', "Ada says the gate is open.")

    report = validate

    assert_not report.valid?
    assert_match(/dialog line must be `@speaker "line"`/, errors(report))
  end

  test "warns about a dialog block with no character speaker" do
    replace("stories/synthetic-story/chapters/01-arrival/02-the-hall.md",
      '@[[character:ada]] "There is nothing here."', '@warden "There is nothing here."')

    report = validate

    assert report.valid?, errors(report)
    assert_match(/no `@\[\[character:…\]\]` speaker/, warnings(report))
  end

  test "warns about a scene frontmatter key that has no column" do
    replace("stories/synthetic-story/chapters/01-arrival/01-the-gate.md", "branch: main", "branch: main\nstatus: draft")

    report = validate

    assert report.valid?, errors(report)
    assert_match(/scene: unknown frontmatter key `status`/, warnings(report))
  end

  test "refuses a scene without a title heading" do
    replace("stories/synthetic-story/chapters/01-arrival/01-the-gate.md", "# The gate\n\n", "")

    report = validate

    assert_not report.valid?
    assert_match(/scene needs a `# Title` heading/, errors(report))
  end

  test "warns when a scene title heading disagrees with its frontmatter" do
    replace("stories/synthetic-story/chapters/01-arrival/01-the-gate.md", "# The gate", "# The other gate")

    report = validate

    assert report.valid?, errors(report)
    assert_match(/scene title heading `The other gate` does not match frontmatter title `The gate`/, warnings(report))
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

  test "accepts a faction that still carries type, home, and status in frontmatter" do
    replace("universe/factions/wardens.md", "slug: wardens\n",
      "slug: wardens\ntype: \"militia\"\nhome: \"[[location:keep]]\"\nstatus: active\n")

    report = validate

    assert report.valid?, errors(report)
    assert_empty report.warnings
  end

  test "accepts a location and an item that still carry their body fields in frontmatter" do
    replace("universe/locations/keep.md", "slug: keep\n",
      "slug: keep\ntype: \"installation\"\ncontroller: \"[[faction:wardens]]\"\nstatus: active\n")
    replace("universe/tech/lantern.md", "slug: lantern\n",
      "slug: lantern\ntype: \"artifact\"\ninvented_by: \"[[faction:wardens]]\"\nstatus: \"operational\"\n")

    report = validate

    assert report.valid?, errors(report)
    assert_empty report.warnings
  end

  test "accepts a plot that still carries its body fields in frontmatter" do
    replace("stories/synthetic-story/plots/the-lantern.md", "slug: the-lantern\n",
      "slug: the-lantern\ntype: \"arc\"\nstatus: \"open\"\nowner_pov: \"ada\"\nopened_in: B-001\n")

    report = validate

    assert report.valid?, errors(report)
    assert_empty report.warnings
  end

  test "requires a plot name and slug" do
    replace("stories/synthetic-story/plots/the-lantern.md", "name: The lantern\n", "")

    report = validate

    assert_not report.valid?
    assert_match(/plot: missing required frontmatter key `name`/, errors(report))
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

  test "reads the what-line as the name and the item's whole text as the statement" do
    canon_ledger("- K1. The lantern built before the first winter\n\n" \
      "  The lantern was built before the *first* winter.\n\n" \
      "  A second paragraph.")

    rule = validate.canon_rules.first

    assert_equal "The lantern built before the first winter", rule.name
    assert_equal "k1", rule.slug
    assert_equal "The lantern built before the first winter\n\n" \
      "The lantern was built before the first winter.\n\n" \
      "A second paragraph.", rule.statement
    assert_nil rule.source
  end

  test "ends an item at a group heading without changing its ledger" do
    canon_ledger("- K1. The lantern built before the first winter\n\n" \
      "  The lantern was built before the first winter.\n\n" \
      "### Later\n\n" \
      "- K2. The gate that came later\n\n" \
      "  The gate came later.")

    report = validate

    assert report.valid?, errors(report)
    assert_equal "The lantern was built before the first winter.", report.canon_rules.first.statement.lines.last.strip
    assert_equal "The gate that came later", report.canon_rules.second.name
    assert_equal "locked", report.canon_rules.second.canon_type
  end

  test "still reads the older bold item form" do
    canon_ledger("- **K1 - Trigger.** The lantern was built before the first winter.")

    report = validate

    assert report.valid?, errors(report)
    rule = report.canon_rules.first
    assert_equal "Trigger", rule.name
    assert_equal "The lantern was built before the first winter.", rule.statement
    assert_includes rule.source, "The lantern was built before the first winter."
  end

  test "keeps the older item's whole text as its source" do
    canon_ledger("- **K1.** The lantern was built before the first winter, and the\n" \
      "  wall around it is younger.\n\n" \
      "  A second paragraph says the gate came later.")

    rule = validate.canon_rules.first

    assert_equal "The lantern was built before the first winter, and the wall around it is younger.",
      rule.statement
    assert_includes rule.source, "The lantern was built before the first winter, and the\nwall around it is younger."
    assert_includes rule.source, "A second paragraph says the gate came later."
  end

  test "strips markdown and source-file paths from a canon item" do
    canon_ledger("- K1. The lantern built before the first winter\n\n" \
      "  The **lantern** was built before the *first* winter, as " \
      "`universe/canon/mechanism.md` records.\n\n" \
      "  See the `README.md` for `code`.\n\n" \
      "  ~~Old wording.~~ The table below is a note.\n\n" \
      "  | Band | Meaning |\n  |---|:---:|\n  | 1 | now |\n\n" \
      "  - a bullet\n  - another")

    rule = validate.canon_rules.first

    assert_equal "The lantern built before the first winter\n\n" \
      "The lantern was built before the first winter, as records.\n\n" \
      "See the for code.\n\n" \
      "Old wording. The table below is a note.\n\n" \
      "Band · Meaning\n\n1 · now\n\na bullet\nanother", rule.statement
    refute_includes rule.statement, "**"
    refute_includes rule.statement, "`"
    refute_includes rule.statement, "|"
    refute_includes rule.statement, "~~"
    refute_includes rule.statement, "mechanism.md"
    refute_includes rule.statement, "README.md"
  end

  test "removes a citation tail from an older item's title and keeps it in the source" do
    canon_ledger("- **K1 — Light (Amended by K27).** The lantern was built before the first winter.")

    rule = validate.canon_rules.first

    assert_equal "Light", rule.name
    assert_includes rule.source, "(Amended by K27)"
  end

  test "skips a leading amendment note when it names an untitled older item" do
    canon_ledger("- **K1.** *(Amended by K27.)* The lantern was built before the first winter.\n\n" \
      "  The note stays in the passage.")

    rule = validate.canon_rules.first

    assert_equal "The lantern was built before the first winter.", rule.name
    assert_equal "The lantern was built before the first winter.", rule.statement
    assert_includes rule.source, "(Amended by K27.) The lantern was built before the first winter."
  end

  test "names a canon item with no what-line after its own statement" do
    canon_ledger("- K1.\n\n  The lantern was built before the first winter.")

    rule = validate.canon_rules.first

    assert_equal "K1", rule.id
    assert_equal "The lantern was built before the first winter.", rule.name
  end

  test "requires canon ids to be unique" do
    canon_ledger("- K1. The lantern built before the first winter\n\n  The lantern was built first.",
      "- K1. A duplicate\n\n  A duplicate item.")

    report = validate

    assert_not report.valid?
    assert_match(/canon id K1 is already defined/, errors(report))
  end

  test "requires the canon ledger README" do
    FileUtils.rm(File.join(@root, "universe/canon/README.md"))

    report = validate

    assert_not report.valid?
    assert_match(%r{universe/canon/README\.md is required}, errors(report))
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

    # Replaces the fixture's canon area with the given items, then the ledger's
    # own L1, D1, and O-I1 so a scene's references to them still resolve.
    def canon_ledger(*items)
      overwrite("universe/canon/mechanism.md",
        "# Canon: mechanism\n\n## Locked\n\n#{items.join("\n\n")}\n\n" \
        "- L1. Light burns only while someone holds the lantern\n\n" \
        "  The lantern burns only while someone holds it.\n\n" \
        "- D1. A lantern left on the ground goes dark\n\n" \
        "  A lantern left on the ground goes dark.\n\n" \
        "## Open\n\n" \
        "- O-I1. Who built the first lantern\n\n" \
        "  Who built the first lantern?\n")
    end

    def errors(report)
      report.errors.map(&:to_s).join("\n")
    end

    def warnings(report)
      report.warnings.map(&:to_s).join("\n")
    end
end
