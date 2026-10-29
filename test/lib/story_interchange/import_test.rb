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

  test "writes characters and factions from frontmatter and profile sections" do
    universe = import.call.universe

    character = universe.characters.find_by!(slug: "ada")
    assert_equal "Ada", character.name
    assert_equal "The engineer trusted by The Wardens to keep the lantern lit.", character.at_a_glance
    assert_equal "To ask someone else to carry it to [[keep]].", character.needs
    assert_equal "That the dark is only a weather problem.", character.lies_to_self
    assert_equal "| Trait A | Trait B |\n|---|---|\n| careful | impatient |", character.contradictions
    assert_equal "- counts the wick\n- lies about the count", character.under_pressure_they
    assert_equal "Leaves the lantern on the ground.", character.never
    assert_nil character.pronouns
    assert_nil character.aliases
    # An affiliation is reported, not guessed into Faction membership.
    assert_empty character.factions

    faction = universe.factions.find_by!(slug: "wardens")
    assert_equal "The Wardens", faction.name
    assert_equal "Keep the gate open.", faction.mission
    assert_equal "Keep the gate closed to everyone else.", faction.actual_aims
    assert_includes faction.structure, "Leadership: a captain."
    assert_includes faction.internal_divisions, "the gate watch"
    assert_includes faction.resources, "control of the road"
    assert_equal "Abandon the gate.", faction.would_never
    assert_equal "Bar the hall when the lantern arrives.", faction.would_absolutely
  end

  test "resolves a reference to a record this run writes and leaves the rest as written" do
    universe = import.call.universe

    character = universe.characters.find_by!(slug: "ada")
    assert_includes character.at_a_glance, "The Wardens"
    assert_not_includes character.at_a_glance, "[[wardens]]"
    assert_includes character.needs, "[[keep]]"
  end

  test "reports every character and faction item it does not write" do
    report = import.plan.report

    characters = StoryInterchange::Importers::Characters.reported(report)
    assert_equal [
      "ada: Voice",
      "ada: State of knowledge",
      "ada: Relationships",
      "ada: Arc",
      "ada: Open questions",
      "ada: role",
      "ada: affiliation",
      "ada: status",
      "ada: first_appears",
      "ada: [[keep]]"
    ], characters

    factions = StoryInterchange::Importers::Factions.reported(report)
    assert_equal [
      "wardens: Register",
      "wardens: The two rivals",
      "wardens: Relationships",
      "wardens: Open questions",
      "wardens: type",
      "wardens: home",
      "wardens: status"
    ], factions
  end

  test "a second import of an unchanged source writes the same records" do
    first = import.call.universe
    characters = character_records(first.characters)
    factions = faction_records(first.factions)

    second = import.call.universe

    assert_equal characters, character_records(second.characters)
    assert_equal factions, faction_records(second.factions)
  end

  test "creates the universe its directory names and writes one rule per K/L/D item" do
    result = import.call

    assert_equal "synthetic-universe", result.universe.slug
    assert_equal "Synthetic Universe", result.universe.name
    assert_equal @owner, result.universe.owner
    assert_not result.replaced
    assert_equal 3, result.universe.canon_rules.count

    rule = result.universe.canon_rules.find_by(statement: "The lantern burns only while someone holds it.")
    assert_includes rule.source, "Canon: universe/canon/mechanism.md"

    outcome = result.outcomes.first
    assert_equal 3, outcome.created
    assert_equal [ "O-I1" ], outcome.skipped
  end

  test "replaces an existing universe by soft-deleting it and creating a fresh one" do
    first = import.call

    second = import.call

    assert second.replaced
    assert_not_equal first.universe.id, second.universe.id
    assert Universe.with_deleted.find(first.universe.id).deleted?
    assert_equal 1, Universe.where(slug: "synthetic-universe").count
    assert_equal 3, second.universe.canon_rules.count
  end

  test "keeps the replaced universe's privacy and collaboration mode" do
    first = import.call
    first.universe.update!(private: true, collaboration_mode: "wikipedia")

    second = import.call

    assert second.universe.private?
    assert second.universe.wikipedia?
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
    assert_equal [ "Canon rules", "Characters", "Factions" ], plan.slices.map { |slice| I18n.t(slice.label_key) }
    assert_equal [ 3, 1, 1 ], plan.slices.map { |slice| slice.preview(plan.report) }
    assert_equal [ "O-I1" ], plan.slices.first.reported(plan.report)
    assert_includes plan.slices.second.reported(plan.report), "ada: Voice"
    assert_equal 0, Universe.where(slug: "synthetic-universe").count
  end

  private
    def import
      StoryInterchange::Import.new(@root, owner: @owner)
    end

    def character_records(collection)
      collection.order(:slug).pluck(:slug, :name, :at_a_glance, :wants, :needs, :lies_to_self,
        :contradictions, :under_pressure_they, :never)
    end

    def faction_records(collection)
      collection.order(:slug).pluck(:slug, :name, :mission, :actual_aims, :structure,
        :internal_divisions, :resources, :would_never, :would_absolutely)
    end
end
