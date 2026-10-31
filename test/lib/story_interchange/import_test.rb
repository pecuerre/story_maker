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
    assert_equal "The Wardens", item.origin
    # A rule reference is a citation, not a record this run writes.
    assert_includes item.constraints, "[[rule:D1]]"
  end

  test "writes a location from its profile sections, grouped answers, and flat hierarchy" do
    universe = import.call.universe

    location = universe.locations.find_by!(slug: "keep")
    assert_equal "The Keep", location.name
    assert_equal "A square of stone around one gate, with a hall behind it.", location.description
    # A labelled list item fills the answer its label names, and one item may
    # name several answers.
    assert_equal "a gate that is taller than the wall.", location.sensory_sight
    assert_equal "wind through the hinge.", location.sensory_sound
    assert_equal "cold stone, wet rope, ordinary weight.", location.sensory_smell
    assert_equal "cold stone, wet rope, ordinary weight.", location.sensory_touch
    assert_nil location.sensory_taste
    # Prose without a label fills the group's first answer.
    assert_equal "The gate opens onto a yard; the hall is the far side of the yard.",
      location.layout_structure
    assert_nil location.layout_key_areas
    assert_equal "The only road through the winter runs under the gate.", location.significance
    assert_equal "the Wardens.", location.access_controlled_by
    assert_equal "one watch at the gate, none at the hall.", location.access_security
    assert_includes location.access_restrictions, "travellers with a token."
    assert_includes location.access_restrictions, "the ledger."
    # The source is flat, so the record is top-level.
    assert_nil location.parent
  end

  test "writes an item with invented_by as its origin and its sections as profile answers" do
    universe = import.call.universe

    item = universe.items.find_by!(slug: "lantern")
    assert_equal "The Lantern", item.name
    assert_equal "Makes light while it is held.", item.what_it_does
    assert_equal "A wick in a glass case, with a handle and no switch.", item.description
    assert_includes item.how_it_is_used, "1. Hold the handle."
    assert_includes item.side_effects, "A smell of oil."
    assert_equal "Burn while it is on the ground.", item.cannot
    assert_includes item.value, "one flask a night"
    assert_equal "It must stay above the snow (`[[rule:D1]]`).", item.constraints
    assert_includes item.jargon, "the quiet"
    assert_equal "Built before the first winter (K1).", item.history
    assert_equal "The Wardens", item.origin
    assert_nil item.parent
  end

  test "writes each story and its plots, with no scene assignments" do
    universe = import.call.universe

    story = universe.stories.find_by!(slug: "synthetic-story")
    assert_equal "Synthetic Story", story.name
    # The README's prose and reading order are presentation, not data.
    assert_nil story.description

    plot = story.plots.find_by!(slug: "the-lantern")
    assert_equal "The lantern", plot.name
    assert_equal "Can Ada reach the hall before the light fails? `Ada` believes she can.", plot.description
    assert_empty plot.scenes
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

    gate = story.scenes.find_by!(slug: "01-arrival-01-the-gate")
    assert_equal "The gate", gate.name
    assert_equal arrival, gate.section
    assert_equal 0, gate.position
    assert_equal "draft", gate.status
    assert_equal universe.characters.find_by!(slug: "ada"), gate.pov_character
    assert_equal [ universe.locations.find_by!(slug: "keep") ], gate.scene_locations.map(&:location)
    assert_nil gate.datetime

    hall = story.scenes.find_by!(slug: "01-arrival-02-the-hall")
    assert_equal 1, hall.position
    assert_equal "revised", hall.status

    # Prose is one Narration Element per paragraph. The first takes the Scene's
    # title, because the source records no block title; later ones are numbered.
    gate_elements = gate.scene_elements.reorder(:position, :id)
    assert_equal 1, gate_elements.count
    assert_equal "The gate", gate_elements.first.name
    assert_equal "narration", gate_elements.first.kind
    assert_includes gate_elements.first.body, "Ada carries the lantern through the gate"
    assert_includes gate_elements.first.body, "The Wardens"
    assert_not_includes gate_elements.first.body, "[[faction:wardens]]"
    # A rule citation is not an entity reference and stays as written.
    assert_includes gate_elements.first.body, "[[rule:L1]]"

    hall_elements = hall.scene_elements.reorder(:position, :id)
    assert_equal [ "The hall", "The hall (2)" ], hall_elements.map(&:name)
    assert_includes hall_elements.last.body, "Ada sets the lantern down and waits for the warden to speak."
    # The Scene's title heading names the record rather than starting the prose,
    # and a drafting comment never reaches an Element.
    assert_not_includes hall_elements.map(&:body).join("\n"), "## The hall"
    assert_not_includes hall_elements.map(&:body).join("\n"), "drafting note"
  end

  test "reports the scene facts the application has no column for" do
    report = import.plan.report

    assert_equal [
      "01-the-gate: id",
      "01-the-gate: timeline",
      "01-the-gate: branch",
      "01-the-gate: depends_on",
      "02-the-hall: id",
      "02-the-hall: timeline",
      "02-the-hall: branch",
      "02-the-hall: depends_on"
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
    assert_equal [
      "keep: Who is here",
      "keep: Events here",
      "keep: Story rules affecting this place",
      "keep: Open questions",
      "keep: type",
      "keep: controller",
      "keep: status"
    ], locations

    items = reported_items(StoryInterchange::Importers::Items.reported(report))
    assert_equal [
      "lantern: In the story",
      "lantern: Open questions",
      "lantern: type",
      "lantern: status"
    ], items

    assert_empty StoryInterchange::Importers::Stories.reported(report)

    sections = reported_items(StoryInterchange::Importers::Sections.reported(report))
    assert_equal [ "01-arrival: What is here" ], sections
    # Both chapters are Sections this run writes; only the first has a
    # subsection the app cannot store.
    section_list = StoryInterchange::Importers::Sections.records(report)
    assert_equal [ "The Arrival Gate", "Winter" ], section_list.map(&:label)
    assert_equal [ true, false ], section_list.map(&:reported?)

    plots = reported_items(StoryInterchange::Importers::Plots.reported(report))
    assert_equal [
      "the-lantern: Stakes",
      "the-lantern: Players",
      "the-lantern: Status",
      "the-lantern: Decisions taken (author)",
      "the-lantern: Progression",
      "the-lantern: Open questions",
      "the-lantern: Resolved",
      "the-lantern: type",
      "the-lantern: status",
      "the-lantern: owner_pov",
      "the-lantern: opened_in"
    ], plots

    # A slice with no profile still lists its records; none of them can leave
    # content behind.
    canon = StoryInterchange::Importers::Canon.records(report)
    assert_equal 4, canon.size
    assert_not canon.any?(&:reported?)

    stories = StoryInterchange::Importers::Stories.records(report)
    assert_equal [ "Synthetic Story" ], stories.map(&:label)
    assert_not stories.sole.reported?
  end

  test "a reported record names what was left behind, and a whole one carries no note" do
    report = import.plan.report

    keep = StoryInterchange::Importers::Locations.reported(report).sole
    assert_equal "The Keep", keep.label
    assert_equal [
      [ :section, "Who is here" ],
      [ :section, "Events here" ],
      [ :section, "Story rules affecting this place" ],
      [ :section, "Open questions" ],
      [ :frontmatter, "type" ],
      [ :frontmatter, "controller" ],
      [ :frontmatter, "status" ]
    ], keep.notes.map { |note| [ note.kind, note.subject ] }

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
    plots = first.stories.flat_map { |story| story.plots.order(:slug).pluck(:slug, :name, :description) }
    sections = section_records(first)
    scenes = scene_records(first)

    second = import.call.universe

    assert_equal characters, character_records(second.characters)
    assert_equal factions, faction_records(second.factions)
    assert_equal locations, location_records(second.locations)
    assert_equal items, item_records(second.items)
    assert_equal stories, second.stories.pluck(:slug, :name)
    assert_equal plots, second.stories.flat_map { |story| story.plots.order(:slug).pluck(:slug, :name, :description) }
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

    rule = result.universe.canon_rules.find_by(statement: "The lantern burns only while someone holds it.")
    assert_equal "l1", rule.slug
    assert_equal "Light", rule.name
    assert_equal "rule", rule.canon_type
    assert_equal "mechanism", rule.category
    assert_equal "L1 — Light. The lantern burns only while someone holds it.", rule.source

    locked = result.universe.canon_rules.find_by!(slug: "k1")
    assert_equal "The lantern was built before the first winter.", locked.name
    assert_equal "locked", locked.canon_type
    assert_equal "consequence", result.universe.canon_rules.find_by!(slug: "d1").canon_type

    question = result.universe.canon_rules.find_by!(slug: "o-i1")
    assert_equal "open", question.canon_type
    assert_equal "Who built the first lantern?", question.name
    assert_includes question.source, "Who built the first lantern?"

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
    assert_equal [ "Canon rules", "Factions", "Characters", "Locations", "Items", "Stories", "Sections", "Scenes", "Plots" ],
      plan.slices.map { |slice| I18n.t(slice.label_key) }
    assert_equal [ 4, 1, 1, 1, 1, 1, 2, 2, 1 ], plan.slices.map { |slice| slice.preview(plan.report) }
    assert_empty plan.slices.first.reported(plan.report)
    assert_empty plan.slices.third.reported(plan.report)
    assert_equal 0, Universe.where(slug: "synthetic-universe").count
  end

  private
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
      collection.order(:slug).pluck(:slug, :name, :description, :parent_id, *Location::PROFILE_FIELDS)
    end

    def item_records(collection)
      collection.order(:slug).pluck(:slug, :name, :description, :parent_id, :origin, *Item::PROFILE_FIELDS)
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
            scene.scene_locations.map { |link| link.location.slug }.sort,
            scene.scene_elements.reorder(:position, :id).pluck(:name, :kind, :body)
          ]
        end
      end
    end
end
