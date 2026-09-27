module Search
  # The record types a search can return, and the words the interface uses for
  # them. This is the one place a kind is named, so the dropdown, the results
  # badges, and the engine's `kind` filter cannot disagree about what a
  # "character" is.
  #
  # A label is deliberately per *kind* and not per model. The eight taxonomies
  # share the `tag` kind and are told apart by a document's `taxonomy`
  # attribute, so "Character tag" is derived here rather than stored in the
  # index, where a wording change would otherwise need a reindex.
  module Kinds
    LABELS = {
      "universe" => "Universe",
      "story" => "Story",
      "section" => "Section",
      "scene" => "Scene",
      "scene_element" => "Scene element",
      "character" => "Character",
      "location" => "Location",
      "item" => "Item",
      "event" => "Event",
      "relation" => "Relation",
      "ownership" => "Ownership",
      "tag" => "Tag"
    }.freeze

    module_function

    def label_for(kind, taxonomy = nil)
      base = LABELS.fetch(kind.to_s, kind.to_s.humanize)
      return base if taxonomy.blank?

      "#{taxonomy} #{base.downcase}"
    end
  end
end
