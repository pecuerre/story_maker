require "test_helper"
require "rubygems/package"
require "stringio"
require "yaml"
require "zlib"

class UniverseBackup::ArchiveTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @generated_at = Time.utc(2026, 10, 28, 12, 0, 0)
    characters(:character_one).update!(summary: "A character a reader can meet.")
    @archive = UniverseBackup::Archive.new(@universe, generated_at: @generated_at)
    @files = read_archive(@archive)
  end

  test "names the archive from the universe and the generation time" do
    assert_equal "one-backup-20261028-120000.tar.gz", @archive.filename
    assert @files.key?("backup.yml")
    assert @files.key?("README.md")
  end

  test "the manifest names the format, the universe, the counts, and the deferred tables" do
    manifest = YAML.safe_load(@files.fetch("backup.yml"))

    assert_equal "universe-backup", manifest["format"]
    assert_equal UniverseBackup::Archive::FORMAT_VERSION, manifest["format_version"]
    assert_equal "one", manifest.dig("universe", "slug")
    assert_equal @generated_at.iso8601, manifest["generated_at"]
    assert_operator manifest.dig("counts", "characters"), :>=, 1
    assert_includes manifest["deferred_tables"], "universe_memberships"
    assert_includes manifest["deferred_tables"], "drafts"
  end

  test "the data dump is scoped to the universe and includes soft-deleted rows" do
    removed = Character.create!(universe: @universe, name: "Removed character")
    removed.soft_delete
    files = read_archive(UniverseBackup::Archive.new(@universe, generated_at: @generated_at))

    rows = YAML.safe_load(files.fetch("data/characters.yml"))
    ids = rows.map { |row| row["id"] }

    assert_includes ids, characters(:character_one).id
    assert_includes ids, removed.id, "a soft-deleted core row belongs in the lossless copy"
    refute_includes ids, characters(:character_other_universe).id
  end

  test "the dump keeps the HABTM join rows" do
    rows = YAML.safe_load(@files.fetch("data/characters_character_tags.yml"))

    assert_includes rows, {
      "character_id" => characters(:character_one).id,
      "character_tag_id" => character_tags(:character_tag_one).id
    }
  end

  test "the dump includes the records the interchange layout has no place for" do
    %w[
      data/character_tags.yml
      data/routes.yml
      data/story_tropes.yml
      data/events.yml
      data/relations.yml
      data/ownerships.yml
      data/discussions.yml
      data/discussion_messages.yml
    ].each do |path|
      assert @files.key?(path), "expected #{path}"
    end
  end

  test "the dump leaves identity, memberships, and change history out" do
    %w[data/users.yml data/universe_memberships.yml data/drafts.yml data/draft_changes.yml
      data/notifications.yml data/api_tokens.yml].each do |path|
      refute @files.key?(path), "#{path} belongs to the later sensitive slice"
    end
  end

  test "a photo is written once and named by the photo row" do
    photo = Photo.new(universe: @universe, name: "Character one portrait")
    photo.file.attach(io: StringIO.new("stored image bytes"), filename: "portrait.jpg", content_type: "image/jpeg")
    photo.save!
    characters(:character_one).update!(photo: photo)

    archive = UniverseBackup::Archive.new(@universe, generated_at: @generated_at)
    files = read_archive(archive)
    row = YAML.safe_load(files.fetch("data/photos.yml")).find { |record| record["id"] == photo.id }

    assert row
    assert_equal "photos/#{photo.slug}-#{photo.id}.jpg", row["archive_path"]
    assert_equal "stored image bytes", files.fetch(row["archive_path"])
    assert_equal 1, YAML.safe_load(files.fetch("backup.yml")).dig("photos", "count")
  end

  test "projects layout-covered records into readable Markdown" do
    character = @files.fetch("content/one/universe/characters/character-one.md")

    assert_includes character, "slug: character-one"
    assert_includes character, "## At a glance"
    assert_includes character, "— TBD", "a field the database does not store is named as absent"

    assert @files.key?("content/one/universe/canon/README.md")
    assert @files.key?("content/one/universe/canon/magic.md")
    assert @files.key?("content/one/universe/canon/rules.md")

    canon_readme = @files.fetch("content/one/universe/canon/README.md")
    assert_includes canon_readme, "| `magic.md` | magic |"
    assert_includes canon_readme, "| `rules.md` | rules |"

    magic = @files.fetch("content/one/universe/canon/magic.md")
    assert_includes magic, "# Canon: magic"
    assert_includes magic, "## Locked"
    assert_includes magic, "- **K1 — Magic costs a memory.** Magic always costs the caster a memory."

    untitled_area = @files.fetch("content/one/universe/canon/rules.md")
    assert_includes untitled_area, "- **L2 — The night crossing.** The river cannot be crossed at night."
    assert_includes untitled_area, "  Source: Chapter five"
    assert_includes untitled_area, "  Story: story-one"
    assert @files.key?("content/one/stories/story-one/README.md")
    assert @files.keys.any? { |path| path.end_with?("/01-scene-one.md") }
    assert @files.key?("content/one/stories/story-one/chapters/00-ungrouped/01-scene-three.md")
    assert @files.key?("content/one/stories/story-one/plots/plot-one.md")
  end

  test "the archive README says which part is authoritative" do
    readme = @files.fetch("README.md")

    assert_includes readme, "the lossless table dump"
    assert_includes readme, "Users, Universe memberships, drafts"
    assert_includes readme, "Restore is not implemented"
  end

  private
    def read_archive(archive)
      entries = {}
      gzip = Zlib::GzipReader.new(StringIO.new(archive.to_s))
      Gem::Package::TarReader.new(gzip) do |tar|
        tar.each do |entry|
          content = entry.read
          content.force_encoding(Encoding::UTF_8) if entry.full_name.end_with?(".md", ".yml")
          entries[entry.full_name] = content
        end
      end
      entries
    end
end
