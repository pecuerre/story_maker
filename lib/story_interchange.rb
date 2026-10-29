# Reads, validates, and imports a story-interchange source directory.
#
# A source is the author's Markdown-and-YAML tree: one universe under `universe/`
# and one directory per story under `stories/<story>/`. The layout, the records
# it holds, and the validation rules are owned by
# [the feature document](../docs/features/story_interchange.md); the ownership
# decision is in [ADR 0041](../docs/adr/0041-the-story-interchange-is-a-directory-contract.md),
# and the import decision is in
# [ADR 0043](../docs/adr/0043-a-story-interchange-import-replaces-one-universe.md).
#
# The database stays the source of truth, and the source is never modified. This
# module validates a tree so an import can preview it, then writes ordinary
# records from it through one small importer per record type.
module StoryInterchange
  # Validates `path` and returns a `StoryInterchange::Report`. Never writes.
  def self.validate(path)
    Validator.new(path).call
  end

  # The directory the browser-facing import page may read sources from. It is
  # empty unless `STORY_INTERCHANGE_IMPORT_ROOT` names one.
  def self.import_root
    ImportRoot.new(Rails.configuration.x.story_interchange.import_root)
  end
end
