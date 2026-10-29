# The one directory the story-interchange import page may read a source from.
#
# It is a deployment's own configuration, not a universe setting: the page that
# reads it creates and destroys universes, so a browser must never be able to
# name an arbitrary path. Names come from `StoryInterchange::ImportRoot`, which
# refuses anything that is not a real child of this root.
#
# Unset is a normal state. The page explains that no root is configured rather
# than pretending the list is empty, and the command-line task takes its own
# path because a shell already has more access than this restriction bounds.
Rails.application.config.x.story_interchange.import_root =
  ENV["STORY_INTERCHANGE_IMPORT_ROOT"].presence
