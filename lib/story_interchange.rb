# Reads and validates a story-interchange source directory without writing to it.
#
# A source is the author's Markdown-and-YAML tree: one universe under `universe/`
# and one directory per story under `stories/<story>/`. The layout, the records
# it holds, and the validation rules are owned by
# [the feature document](../docs/features/story_interchange.md); the ownership
# decision is in [ADR 0041](../docs/adr/0041-the-story-interchange-is-a-directory-contract.md).
#
# The database stays the source of truth. This module only reads a source so a
# later import slice can write it into ordinary records, and so a later backup
# slice can write the same tree back out.
module StoryInterchange
  # Validates `path` and returns a `StoryInterchange::Report`. Never writes.
  def self.validate(path)
    Validator.new(path).call
  end
end
