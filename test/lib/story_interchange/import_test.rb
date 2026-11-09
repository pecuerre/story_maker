require "test_helper"
require "fileutils"
require "tmpdir"

# The import entry point: what it writes, what it refuses, and the one universe
# it is allowed to replace. The page and the task are thin callers of this, so
# these cases are the run itself rather than the chrome around it.
class StoryInterchangeImportTest < ActiveSupport::TestCase
  FIXTURE = Rails.root.join("test/fixtures/files/story_interchange/synthetic-universe")

  setup do
    @temporary_directory = Dir.mktmpdir("story-interchange-import-test")
    @root = File.join(@temporary_directory, "synthetic-universe")
    FileUtils.cp_r(FIXTURE, @root)
    @owner = users(:user_one)
  end

  teardown do
    FileUtils.remove_entry(@temporary_directory) if File.directory?(@temporary_directory)
  end

  test "writes a character and a faction as a summary and one Markdown description" do
    universe = import.call.universe

    character = universe.characters.find_by!(slug: "ada")
    assert_equal "Ada", character.name
    assert_equal "The engineer trusted by The Wardens to keep the lantern lit.", character.summary
    assert_nil character.pronouns
    assert_nil character.aliases
    # Every profile section except the summary is one description, in source
    # order, with the source's Markdown and typed links kept as written.
    assert_includes character.description, "## Information"
    assert_includes character.description, "## Wants\n\nTo reach the hall before the light fails."
    assert_includes character.description, "## Needs\n\nTo ask someone else to carry it to [[location:keep]]."
    assert_includes character.description, "## Lies about (to herself)"
    assert_includes character.description, "| Trait A | Trait B |\n|---|---|\n| careful | impatient |"
    assert_includes character.description, "## Under pressure they\n\n- counts the wick\n- lies about the count"
    assert_includes character.description, "## Never\n\nLeaves the lantern on the ground."
    assert_includes character.description, "## State of knowledge"
    assert_includes character.description, "## Voice"
    assert_includes character.description, "## Arc"
    assert_includes character.description, "## Open questions"
    # A `[[faction:slug]]` affiliation is a membership, not free text.
    assert_equal [ "wardens" ], character.factions.map(&:slug)

    faction = universe.factions.find_by!(slug: "wardens")
    assert_equal "The Wardens", faction.name
    # `Short summary` is the summary; `Mission` stays a section in the
    # description because both headings are present.
    assert_equal "Keep the gate open.", faction.summary
    # Every section except the summary is one description, in source order,
    # with the source's Markdown kept as written.
    assert_includes faction.description,
      "## Information\n\n- Type: militia\n- Home: [[location:keep]]\n- Status: active\n- Backlog: B-001"
    assert_includes faction.description, "## Mission\n\nHold the gate against the hall."
    assert_includes faction.description, "## Actually for\n\nKeep the gate closed to everyone else."
    assert_includes faction.description, "## Structure\n\n- Leadership: a captain."
    assert_includes faction.description, "## Register\n\nIn-world, the Wardens call a closed gate \"the quiet\"."
    assert_includes faction.description,
      "## Internal split\n\n- The gate watch, and the captain who leads it.\n  Wants: the gate shut at every hour."
    assert_includes faction.description,
      "## Resources\n\n- The gate.\n  Buys: control of the road.\n  Limits: one road."
    assert_includes faction.description, "## Would never\n\nAbandon the gate."
    assert_includes faction.description, "## Would absolutely\n\nBar the hall when the lantern arrives."
    assert_includes faction.description, "## The two rivals"
    assert_includes faction.description, "## Relationships"
    assert_includes faction.description, "## Open questions"
  end

  test "uses Mission as a Faction summary only when there is no Short summary" do
    path = File.join(@root, "universe/factions/wardens.md")
    File.write(path, File.read(path).sub("## Short summary\n\nKeep the gate open.\n\n", ""))

    faction = import.call.universe.factions.find_by!(slug: "wardens")

    assert_equal "Hold the gate against the hall.", faction.summary
    assert_not_includes faction.description, "## Mission"
    assert_includes faction.description, "## Information"
  end

  test "reports an affiliation that names no Faction and keeps it out of membership" do
    path = File.join(@root, "universe/characters/ada.md")
    File.write(path, File.read(path).sub(
      'affiliation: "[[faction:wardens]]"',
      'affiliation: "[[faction:wardens]] · International Lunar Programme"'
    ))

    plan = import.plan
    record = StoryInterchange::Importers::Characters.reported(plan.report).sole
    # The note names the source text that could not become a membership, so the
    # page can say which affiliation was left behind.
    assert_equal [ [ :affiliation, "International Lunar Programme" ] ],
      record.notes.map { |note| [ note.kind, note.subject ] }
    assert_equal [ "ada: affiliation (International Lunar Programme)" ], record.items

    character = import.call.universe.characters.find_by!(slug: "ada")
    assert_equal [ "wardens" ], character.factions.map(&:slug)
  end

  test "resolves a reference in plain prose and keeps a typed link in a description" do
    universe = import.call.universe

    character = universe.characters.find_by!(slug: "ada")
    assert_includes character.summary, "The Wardens"
    assert_not_includes character.summary, "[[faction:wardens]]"
    # The description is the one answer whose references stay as written: the
    # details page turns each one into a link to the record it names.
    assert_includes character.description, "[[location:keep]]"

    item = universe.items.find_by!(slug: "lantern")
    # The item's whole body is its description, so its links stay as written too.
    assert_includes item.description, "[[faction:wardens]]"
    assert_includes item.description, "[[rule:D1]]"
  end

  test "creates a relation tag for every relationship type and one relation per character pair" do
    replace_character_relationships("ada", <<~MARKDOWN.chomp)
      - [[character:bryn|type:crew]] - the engineer [[faction:wardens]] trusts ([[canon:K1]]).
        Leverage: the watch.
    MARKDOWN
    write_character("bryn", "Bryn", <<~MARKDOWN.chomp)
      - [[character:ada|type:boss]] - the engineer he answers to.
        Leverage: the lantern.
    MARKDOWN
    write_character("cy", "Cy", <<~MARKDOWN.chomp)
      - [[character:ada|type:]] - a neighbour with no clear tie.
    MARKDOWN

    import_run = import
    assert_equal 2, StoryInterchange::Importers::Relations.preview(import_run.plan.report)

    universe = import_run.call.universe
    ada = universe.characters.find_by!(slug: "ada")
    bryn = universe.characters.find_by!(slug: "bryn")
    cy = universe.characters.find_by!(slug: "cy")

    # Every stated type becomes a tag, including the one on the reciprocal
    # bullet that did not decide the pair.
    assert_equal %w[boss crew], universe.relation_tags.order(:name).pluck(:name)

    # The files state the same pair from both ends, so one Relation is written.
    # Ada's file sorts first, so its `crew` type is the one that survives.
    relation = universe.relations.find_by!(character1: bryn, character2: ada)
    assert_equal %w[crew], relation.relation_tags.map(&:name)
    # The description is plain text: entity references read as names and canon
    # references as the ids a reader can follow.
    assert_includes relation.description, "the engineer The Wardens trusts (K1)."
    refute_includes relation.description, "[["
    assert_includes relation.description, "Leverage: the watch."

    # A blank type creates an untagged Relation instead of dropping the edge.
    untagged = universe.relations.find_by!(character1: cy, character2: ada)
    assert_empty untagged.relation_tags
    assert_equal "a neighbour with no clear tie.", untagged.description

    assert_equal 2, universe.relations.count
  end

  test "writes a location as one Markdown description and a flat hierarchy" do
    universe = import.call.universe

    location = universe.locations.find_by!(slug: "keep")
    assert_equal "The Keep", location.name
    # Every section lands in the description, in source order, with the source's
    # Markdown and typed links kept as written.
    assert_includes location.description, "## Short summary\n\nA square of stone around one gate, with a hall behind it."
    assert_includes location.description,
      "## Information\n\n- Type: installation\n- Controller: [[faction:wardens]]\n- Status: active\n- Backlog: B-001"
    assert_includes location.description, "## What it is\n\nA square of stone around one gate, with a hall behind it."
    assert_includes location.description,
      "## Sensory\n\n- Sight: a gate that is taller than the wall.\n- Sound: wind through the hinge."
    assert_includes location.description,
      "## Layout\n\nThe gate opens onto a yard; the hall is the far side of the yard."
    assert_includes location.description, "## Why it matters"
    assert_includes location.description, "## Control and access"
    assert_includes location.description, "## History"
    assert_includes location.description, "## Open questions"
    # The source is flat, so the record is top-level.
    assert_nil location.parent
  end

  test "writes an item as one Markdown description and a flat hierarchy" do
    universe = import.call.universe

    item = universe.items.find_by!(slug: "lantern")
    assert_equal "The Lantern", item.name
    # Every section lands in the description, in source order, with the source's
    # Markdown and typed links kept as written.
    assert_includes item.description, "## Short summary\n\nMakes light while it is held."
    assert_includes item.description,
      "## Information\n\n- Type: artifact\n- Invented by: [[faction:wardens]]\n- Status: operational\n- Backlog: B-001"
    assert_includes item.description, "## One line\n\nMakes light while it is held."
    assert_includes item.description,
      "## What it actually is\n\nA wick in a glass case, with a handle and no switch."
    assert_includes item.description, "## How it is operated\n\n1. Hold the handle."
    assert_includes item.description, "## Physical side effects\n\n1. A smell of oil."
    assert_includes item.description, "## Cannot\n\nBurn while it is on the ground."
    assert_includes item.description, "## Costs"
    assert_includes item.description, "## Constraints\n\nIt must stay above the snow (`[[rule:D1]]`)."
    assert_includes item.description, "## Jargon"
    assert_includes item.description, "## History\n\nBuilt before the first winter (K1)."
    assert_includes item.description, "## In the story"
    assert_includes item.description, "## Open questions"
    # The source is flat, so the record is top-level.
    assert_nil item.parent
  end

  test "reports an older item's invented_by frontmatter instead of importing it" do
    path = File.join(@root, "universe/tech/lantern.md")
    content = File.read(path)
      .sub("## Information\n\n- Type: artifact\n- Invented by: [[faction:wardens]]\n- Status: operational\n- Backlog: B-001\n\n", "")
      .sub("slug: lantern\n", "slug: lantern\ntype: \"artifact\"\ninvented_by: \"[[faction:wardens]]\"\nstatus: \"operational\"\n")
    File.write(path, content)

    report = import.plan.report
    record = StoryInterchange::Importers::Items.records(report).sole
    assert_equal [
      [ :frontmatter, "type" ],
      [ :frontmatter, "invented_by" ],
      [ :frontmatter, "status" ]
    ], record.notes.map { |note| [ note.kind, note.subject ] }

    item = import.call.universe.items.find_by!(slug: "lantern")
    assert_not_includes item.description, "The Wardens"
  end

  test "writes each story and its plots, with no scene assignments" do
    universe = import.call.universe

    story = universe.stories.find_by!(slug: "synthetic-story")
    assert_equal "Synthetic Story", story.name
    # The README's prose and reading order are presentation, not data.
    assert_nil story.description

    plot = story.plots.find_by!(slug: "the-lantern")
    assert_equal "The lantern", plot.name
    # `Short summary` is the list row; the identity block and every other
    # section are one Markdown description, headings and links kept as written.
    assert_equal "Can Ada reach the hall before the light fails?", plot.short_summary
    assert_includes plot.description, "## Information"
    assert_includes plot.description, "- Type: arc"
    assert_includes plot.description, "## The question"
    assert_includes plot.description, "`[[character:ada]]` believes she can."
    assert_includes plot.description, "## Stakes"
    assert_includes plot.description, "## Players"
    assert_includes plot.description, "## Open questions"
    assert_not_includes plot.description, "## Short summary"
    assert_empty plot.scenes
  end

  test "reports an older plot's frontmatter keys instead of importing them" do
    path = File.join(@root, "stories/synthetic-story/plots/the-lantern.md")
    File.write(path, File.read(path).sub("slug: the-lantern\n",
      "slug: the-lantern\ntype: \"arc\"\nstatus: \"open\"\nowner_pov: \"ada\"\nopened_in: B-001\n"))

    report = import.plan.report

    assert_equal [
      "the-lantern: type",
      "the-lantern: status",
      "the-lantern: owner_pov",
      "the-lantern: opened_in"
    ], reported_items(StoryInterchange::Importers::Plots.reported(report))
  end

  test "writes each chapter as a section and each scene with its point of view, location, and prose" do
    universe = import.call.universe
    story = universe.stories.find_by!(slug: "synthetic-story")

    arrival = story.sections.find_by!(slug: "01-arrival")
    assert_equal "The Arrival Gate", arrival.name
    assert_equal 0, arrival.position
    assert_nil arrival.parent
    # The README's identity block is the description, with references resolved
    # to names; its `##` subsection has no Section column and is reported.
    assert_includes arrival.description, "Documentation for this chapter directory"
    assert_includes arrival.description, "follows Ada."
    assert_not_includes arrival.description, "[[ada]]"
    assert_not_includes arrival.description, "## What is here"

    winter = story.sections.find_by!(slug: "02-winter")
    assert_equal "Winter", winter.name
    assert_equal 1, winter.position
    assert_empty winter.scenes

    # The run creates one Chapter Section Tag per Story and labels every imported
    # chapter with it.
    chapter_tag = story.section_tags.find_by!(slug: "chapter")
    assert_equal "Chapter", chapter_tag.name
    assert_equal [ chapter_tag ], story.section_tags.to_a
    assert_equal [ chapter_tag ], arrival.section_tags.to_a
    assert_equal [ chapter_tag ], winter.section_tags.to_a

    gate = story.scenes.find_by!(slug: "01-arrival-01-the-gate")
    assert_equal "The gate", gate.name
    assert_equal arrival, gate.section
    assert_equal 0, gate.position
    assert_equal "draft", gate.status
    assert_equal universe.characters.find_by!(slug: "ada"), gate.pov_character
    assert_equal [ universe.locations.find_by!(slug: "keep") ], gate.scene_locations.map(&:location)
    # `moment` is the parseable twin of `timeline`, so a concrete value is the
    # Scene's own in-world time as well as its Event's.
    assert_equal Time.utc(2050, 1, 1, 20), gate.datetime

    hall = story.scenes.find_by!(slug: "01-arrival-02-the-hall")
    assert_equal 1, hall.position
    # A relation is not a point, so it does not fill the Scene's own datetime;
    # the Events slice resolves it on the Event.
    assert_nil hall.datetime
    # The new scene format keeps no writing status in the source, so an imported
    # Scene starts in the vocabulary's default state.
    assert_equal "draft", hall.status

    # One Element per `##` block: a Narration block is one Element carrying its
    # paragraphs, and a Dialog block is a Dialogue Element with its turns.
    gate_elements = gate.scene_elements.reorder(:position, :id)
    assert_equal [ "narration", "dialogue" ], gate_elements.map(&:kind)
    assert_equal [ "The gate", "The gate (2)" ], gate_elements.map(&:name)
    assert_includes gate_elements.first.body, "Ada carries the lantern through the gate"
    assert_includes gate_elements.first.body, "The Wardens"
    assert_not_includes gate_elements.first.body, "[[faction:wardens]]"
    # A rule citation is not an entity reference and stays as written.
    assert_includes gate_elements.first.body, "[[rule:L1]]"

    dialogue = gate_elements.last
    turns = dialogue.scene_dialogue_turns.reorder(:position, :id)
    assert_equal [ "The gate is open.", "gatekeeper: It opens for the lantern.", "Then it stays barred to The Wardens." ],
      turns.map(&:body)
    assert_equal [ universe.characters.find_by!(slug: "ada"), nil, universe.characters.find_by!(slug: "ada") ],
      turns.map(&:speaker)
    # `@gatekeeper` names no Character file, so it becomes a non-character turn
    # whose line keeps the tag rather than a speaker the Universe does not have.
    assert turns.second.non_character_speaker?

    hall_elements = hall.scene_elements.reorder(:position, :id)
    assert_equal [ "narration", "dialogue", "narration" ], hall_elements.map(&:kind)
    assert_equal [ "The hall", "The hall (2)", "The hall (3)" ], hall_elements.map(&:name)
    assert_includes hall_elements.first.body, "[[rule:D1]]"
    assert_equal [ "There is nothing here.", "warden: Then we wait." ],
      hall_elements.second.scene_dialogue_turns.reorder(:position, :id).map(&:body)
    assert_includes hall_elements.last.body, "Ada sets the lantern down and waits for the warden to speak."
    # The Scene's title heading names the record rather than starting the prose,
    # and the drafting contract never reaches an Element.
    all_bodies = gate_elements.map(&:body).join("\n") + hall_elements.map(&:body).join("\n")
    assert_not_includes all_bodies, "## The gate"
    assert_not_includes all_bodies, "DRAFTING CONTRACT"
  end

  test "writes one event per scene, dates it from moment, and links it to the scene" do
    universe = import.call.universe
    story = universe.stories.find_by!(slug: "synthetic-story")
    gate = story.scenes.find_by!(slug: "01-arrival-01-the-gate")
    hall = story.scenes.find_by!(slug: "01-arrival-02-the-hall")

    gate_event = gate.events.sole
    hall_event = hall.events.sole

    assert_equal "The gate", gate_event.title
    assert_equal Time.utc(2050, 1, 1, 20), gate_event.start_datetime
    assert_equal "The hall", hall_event.title
    # A span is both a relation and, when its target has a date, a computed
    # start: one hour after the gate.
    assert_equal Time.utc(2050, 1, 1, 21), hall_event.start_datetime
    assert_equal gate_event, hall_event.after_event
    assert_nil hall_event.before_event
    assert_nil hall_event.simultaneous_event
  end

  test "writes a before, simultaneous, and bare direction moment as event relations" do
    write("stories/synthetic-story/chapters/02-winter/01-before.md", <<~MARKDOWN)
      ---
      id: B-101
      title: Before
      pov: ada
      location: keep
      timeline: "before the gate"
      moment: "before 01-arrival/01-the-gate"
      branch: main
      ---

      # Before

      ## Narration

      Before the gate opens.
    MARKDOWN
    write("stories/synthetic-story/chapters/02-winter/02-same.md", <<~MARKDOWN)
      ---
      id: B-102
      title: Same
      pov: ada
      location: keep
      timeline: "at the gate"
      moment: "at the same time as 01-arrival/01-the-gate"
      branch: main
      ---

      # Same

      ## Narration

      The same instant as the gate.
    MARKDOWN
    write("stories/synthetic-story/chapters/02-winter/03-after.md", <<~MARKDOWN)
      ---
      id: B-103
      title: After
      pov: ada
      location: keep
      timeline: "after the gate"
      moment: "after 01-arrival/01-the-gate"
      branch: main
      ---

      # After

      ## Narration

      After the gate closes.
    MARKDOWN

    universe = import.call.universe
    story = universe.stories.find_by!(slug: "synthetic-story")
    gate_event = story.scenes.find_by!(slug: "01-arrival-01-the-gate").events.sole
    before_event = story.scenes.find_by!(slug: "02-winter-01-before").events.sole
    same_event = story.scenes.find_by!(slug: "02-winter-02-same").events.sole
    after_event = story.scenes.find_by!(slug: "02-winter-03-after").events.sole

    assert_equal gate_event, before_event.before_event
    assert_nil before_event.after_event
    assert_equal gate_event, same_event.simultaneous_event
    # A relation-only scene with a dated target inherits that instant, so it is
    # still placeable on a chronological listing.
    assert_equal gate_event.start_datetime, same_event.start_datetime
    assert_equal gate_event, after_event.after_event
    assert_nil before_event.start_datetime
    assert_nil after_event.start_datetime
  end

  test "joins a dialogue turn that wraps across physical lines" do
    path = File.join(@root, "stories/synthetic-story/chapters/01-arrival/01-the-gate.md")
    File.write(path, File.read(path).sub(
      '@[[character:ada]] "The gate is open."',
      "@[[character:ada]] \"The gate is open,\nand the wick is low.\""
    ))

    universe = import.call.universe
    gate = universe.stories.find_by!(slug: "synthetic-story").scenes.find_by!(slug: "01-arrival-01-the-gate")
    turns = gate.scene_elements.reorder(:position, :id).last.scene_dialogue_turns.reorder(:position, :id)

    assert_includes turns.map(&:body), "The gate is open, and the wick is low."
    assert_not_includes turns.map(&:body), "The gate is open,\nand the wick is low."
  end

  test "writes a scene's drafting contract to its own column" do
    universe = import.call.universe
    story = universe.stories.find_by!(slug: "synthetic-story")
    gate = story.scenes.find_by!(slug: "01-arrival-01-the-gate")

    assert_includes gate.drafting_contract, "one place, one beat of time"
    assert_includes gate.drafting_contract, "can the lantern"
    assert_includes gate.drafting_contract, "the wick fails"
    # An entity reference in the note reads as prose, like any other answer.
    assert_includes gate.drafting_contract, "with The Wardens watching?"
    assert_not_includes gate.drafting_contract, "<!--"
  end

  test "imports a bare speaker as a non-character turn with the tag in the line" do
    path = File.join(@root, "stories/synthetic-story/chapters/01-arrival/02-the-hall.md")
    File.write(path, File.read(path).sub('@[[character:ada]] "There is nothing here."', '@other "There is nothing here."'))

    universe = import.call.universe
    hall = universe.stories.find_by!(slug: "synthetic-story").scenes.find_by!(slug: "01-arrival-02-the-hall")
    dialogue = hall.scene_elements.reorder(:position, :id).second

    # Neither line names a Character file, so both become non-character turns
    # whose bodies keep the tag instead of being dropped as prose.
    assert_equal "dialogue", dialogue.kind
    turns = dialogue.scene_dialogue_turns.reorder(:position, :id)
    assert_equal [ "other: There is nothing here.", "warden: Then we wait." ], turns.map(&:body)
    assert turns.all?(&:non_character_speaker?)
    assert_empty turns.filter_map(&:speaker)
  end

  test "reports the scene facts the application has no column for" do
    report = import.plan.report

    assert_equal [
      "01-the-gate: id",
      "01-the-gate: timeline",
      "01-the-gate: branch",
      "02-the-hall: id",
      "02-the-hall: timeline",
      "02-the-hall: branch"
    ], reported_items(StoryInterchange::Importers::Scenes.reported(report))
  end

  test "reports every item of every slice it does not write" do
    report = import.plan.report

    characters = reported_items(StoryInterchange::Importers::Characters.reported(report))
    assert_empty characters
    # Every character is listed even when nothing is left behind; only the ones
    # with leftover content are reported.
    character_list = StoryInterchange::Importers::Characters.records(report)
    assert_equal [ "Ada" ], character_list.map(&:label)
    assert_not character_list.sole.reported?

    factions = reported_items(StoryInterchange::Importers::Factions.reported(report))
    assert_empty factions

    locations = reported_items(StoryInterchange::Importers::Locations.reported(report))
    assert_empty locations

    items = reported_items(StoryInterchange::Importers::Items.reported(report))
    assert_empty items

    assert_empty StoryInterchange::Importers::Stories.reported(report)

    sections = reported_items(StoryInterchange::Importers::Sections.reported(report))
    assert_equal [ "01-arrival: What is here" ], sections
    # Both chapters are Sections this run writes; only the first has a
    # subsection the app cannot store.
    section_list = StoryInterchange::Importers::Sections.records(report)
    assert_equal [ "The Arrival Gate", "Winter" ], section_list.map(&:label)
    assert_equal [ true, false ], section_list.map(&:reported?)

    plots = reported_items(StoryInterchange::Importers::Plots.reported(report))
    assert_empty plots

    # A slice with no profile still lists its records; none of them can leave
    # content behind.
    canon = StoryInterchange::Importers::Canon.records(report)
    assert_equal 4, canon.size
    assert_not canon.any?(&:reported?)

    stories = StoryInterchange::Importers::Stories.records(report)
    assert_equal [ "Synthetic Story" ], stories.map(&:label)
    assert_not stories.sole.reported?

    # The Events slice names its records after their Scenes, and every accepted
    # moment shape is stored whole.
    events = StoryInterchange::Importers::Events.records(report)
    assert_equal [ "The gate", "The hall" ], events.map(&:label)
    assert_not events.any?(&:reported?)
  end

  test "a reported record names what was left behind, and a whole one carries no note" do
    report = import.plan.report

    # The whole Location body lands in the description, so nothing is left
    # behind and the page shows the name alone.
    keep = StoryInterchange::Importers::Locations.records(report).sole
    assert_equal "The Keep", keep.label
    assert_empty keep.notes
    assert_not keep.reported?

    wardens = StoryInterchange::Importers::Factions.records(report).sole
    assert_equal "The Wardens", wardens.label
    # The whole body lands in the description, so nothing is left behind and
    # the page shows the name alone.
    assert_empty wardens.notes
    assert_not wardens.reported?

    arrival = StoryInterchange::Importers::Sections.reported(report).sole
    assert_equal "The Arrival Gate", arrival.label
    assert_equal [ [ :section, "What is here" ] ], arrival.notes.map { |note| [ note.kind, note.subject ] }
  end

  test "a second import of an unchanged source writes the same records" do
    first = import.call.universe
    characters = character_records(first.characters)
    factions = faction_records(first.factions)
    locations = location_records(first.locations)
    items = item_records(first.items)
    stories = first.stories.pluck(:slug, :name)
    plots = first.stories.flat_map { |story| story.plots.order(:slug).pluck(:slug, :name, :short_summary, :description) }
    sections = section_records(first)
    scenes = scene_records(first)

    second = import.call.universe

    assert_equal characters, character_records(second.characters)
    assert_equal factions, faction_records(second.factions)
    assert_equal locations, location_records(second.locations)
    assert_equal items, item_records(second.items)
    assert_equal stories, second.stories.pluck(:slug, :name)
    assert_equal plots, second.stories.flat_map { |story| story.plots.order(:slug).pluck(:slug, :name, :short_summary, :description) }
    assert_equal sections, section_records(second)
    assert_equal scenes, scene_records(second)
  end

  test "creates the universe its directory names and writes one rule per K/L/D/O item" do
    result = import.call

    assert_equal "synthetic-universe", result.universe.slug
    assert_equal "Synthetic Universe", result.universe.name
    assert_equal @owner, result.universe.owner
    assert_not result.replaced
    assert_equal 4, result.universe.canon_rules.count

    rule = result.universe.canon_rules.find_by!(slug: "l1")
    assert_equal "Light burns only while someone holds the lantern", rule.name
    assert_equal "rule", rule.canon_type
    assert_equal "mechanism", rule.category
    assert_equal "Light burns only while someone holds the lantern\n\nThe lantern burns only while someone holds it.",
      rule.statement
    assert_nil rule.source

    locked = result.universe.canon_rules.find_by!(slug: "k1")
    assert_equal "The lantern built before the first winter", locked.name
    assert_equal "locked", locked.canon_type
    assert_equal "consequence", result.universe.canon_rules.find_by!(slug: "d1").canon_type

    question = result.universe.canon_rules.find_by!(slug: "o-i1")
    assert_equal "open", question.canon_type
    assert_equal "Who built the first lantern", question.name
    assert_equal "Who built the first lantern\n\nWho built the first lantern?", question.statement
    assert_nil question.source

    outcome = result.outcomes.first
    assert_equal 4, outcome.created
    assert_empty outcome.reported
  end

  test "replaces an existing universe by soft-deleting it and creating a fresh one" do
    first = import.call

    second = import.call

    assert second.replaced
    assert_not_equal first.universe.id, second.universe.id
    assert Universe.with_deleted.find(first.universe.id).deleted?
    assert_equal 1, Universe.where(slug: "synthetic-universe").count
    assert_equal 4, second.universe.canon_rules.count
  end

  test "keeps the replaced universe's privacy and collaboration mode" do
    first = import.call
    first.universe.update!(private: true, collaboration_mode: "wikipedia")

    second = import.call

    assert second.universe.private?
    assert second.universe.wikipedia?
  end

  test "records the run in the same transaction as the write it describes" do
    result = import.call

    run = result.run
    assert_equal @owner, run.user
    assert_equal "synthetic-universe", run.source
    assert_equal result.universe.name, run.universe_name
    assert_equal result.universe.slug, run.universe_slug
    assert_not run.replaced?
    assert_equal result.outcomes.map(&:created), run.slices.map(&:created)
    # The run keeps every record, not only the reported ones, so its page can
    # list the whole slice after the source is gone.
    assert_equal(
      result.outcomes.flat_map(&:records).map { |record| [ record.name, record.slug, record.reported?, record.items ] },
      run.slices.flat_map(&:records).map { |record| [ record.name, record.slug, record.reported?, record.items ] }
    )
    assert_equal 1, StoryInterchangeRun.count
  end

  test "records a run for a replaced universe, and none for a refused one" do
    import.call
    second = import.call

    assert second.run.replaced?
    assert_equal 2, StoryInterchangeRun.count

    Draft.create!(user: @owner, universe: second.universe)
    assert_raises(StoryInterchange::Import::Refused) { import.call }

    assert_equal 2, StoryInterchangeRun.count
    assert_not second.universe.reload.deleted?
  end

  test "does not touch another universe" do
    other = universes(:universe_one)
    rules_before = other.canon_rules.count

    import.call

    assert_not other.reload.deleted?
    assert_equal rules_before, other.canon_rules.count
  end

  test "refuses to replace a universe with an open draft" do
    existing = import.call.universe
    draft = Draft.create!(user: @owner, universe: existing)

    refusal = assert_raises(StoryInterchange::Import::Refused) { import.call }

    assert_includes refusal.plan.open_drafts.map(&:id), draft.id
    assert_not existing.reload.deleted?
    assert_equal 1, Universe.where(slug: "synthetic-universe").count
  end

  test "refuses to replace a universe with a member other than the importer" do
    existing = import.call.universe
    member = users(:user_two)
    UniverseMembership.create!(universe: existing, user: member, access_level: "read")

    refusal = assert_raises(StoryInterchange::Import::Refused) { import.call }

    assert_includes refusal.plan.other_members, member
    assert_not existing.reload.deleted?
  end

  test "refuses an invalid source without creating a universe" do
    FileUtils.rm(File.join(@root, "universe/canon/README.md"))

    refusal = assert_raises(StoryInterchange::Import::Refused) { import.call }

    assert_not refusal.plan.valid?
    assert_equal 0, Universe.where(slug: "synthetic-universe").count
  end

  test "the plan previews the registered slices before anything is written" do
    plan = import.plan

    assert plan.importable?
    assert_equal [ "Canon rules", "Factions", "Characters", "Relations", "Locations", "Items", "Stories",
      "Sections", "Scenes", "Events", "Plots" ],
      plan.slices.map { |slice| I18n.t(slice.label_key) }
    assert_equal [ 4, 1, 1, 0, 1, 1, 1, 2, 2, 2, 1 ], plan.slices.map { |slice| slice.preview(plan.report) }
    assert_empty plan.slices.first.reported(plan.report)
    assert_empty plan.slices.third.reported(plan.report)
    assert_equal 0, Universe.where(slug: "synthetic-universe").count
  end

  private
    def write(relative_path, content)
      path = File.join(@root, relative_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end

    def write_character(slug, name, relationships)
      write("universe/characters/#{slug}.md", <<~MARKDOWN)
        ---
        name: #{name}
        slug: #{slug}
        affiliation: "[[faction:wardens]]"
        ---

        # #{name}

        ## Short summary

        A member of the gate watch.

        ## Relationships

        #{relationships}
      MARKDOWN
    end

    def replace_character_relationships(slug, body)
      path = File.join(@root, "universe/characters/#{slug}.md")
      content = File.read(path)
      old = "## Relationships\n\n| Character | Dynamic | Leverage |\n|---|---|---|\n| — | — | — |"
      assert_includes content, old, "the fixture's relationship table changed"
      File.write(path, content.sub(old, "## Relationships\n\n#{body}\n"))
    end

    def reported_items(records)
      records.flat_map(&:items)
    end

    def import
      StoryInterchange::Import.new(@root, owner: @owner)
    end

    def character_records(collection)
      collection.order(:slug).pluck(:slug, :name, :summary, :description)
    end

    def faction_records(collection)
      collection.order(:slug).pluck(:slug, :name, :summary, :description)
    end

    def location_records(collection)
      collection.order(:slug).pluck(:slug, :name, :description, :parent_id)
    end

    def item_records(collection)
      collection.order(:slug).pluck(:slug, :name, :description, :parent_id)
    end

    def section_records(universe)
      universe.stories.flat_map { |story| story.sections.order(:slug).pluck(:slug, :name, :position, :description) }
    end

    def scene_records(universe)
      universe.stories.flat_map do |story|
        story.scenes.order(:slug).map do |scene|
          [
            scene.slug,
            scene.name,
            scene.status,
            scene.position,
            scene.section&.slug,
            scene.pov_character&.slug,
            scene.drafting_contract,
            scene.scene_locations.map { |link| link.location.slug }.sort,
            scene.scene_elements.reorder(:position, :id).map do |element|
              [ element.name, element.kind, element.body,
                element.scene_dialogue_turns.reorder(:position, :id).map { |turn| [ turn.speaker&.slug, turn.body ] } ]
            end
          ]
        end
      end
    end
end
