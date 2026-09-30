module Search
  # The record types a search can return, and the words the interface uses for
  # them. This is the one place a kind is named, so the dropdown, the results
  # badges, and the engine's `kind` filter cannot disagree about what a
  # "character" is.
  #
  # A label is deliberately per *kind* and not per model. The eight taxonomies
  # share the `tag` kind and are told apart by a document's `taxonomy`
  # attribute, so "Character tag" is named here rather than stored in the
  # index, where a wording change would otherwise need a reindex.
  #
  # Both maps hold *keys*, never translated strings, for the reason the rest of
  # the application follows: this file is loaded once, and a label resolved here
  # would be the language of whichever request loaded it first. `label_for`
  # resolves per request instead, and a kind or taxonomy this version does not
  # know falls back to its own value rather than to a missing translation — a
  # value this version cannot name is not copy it can invent.
  #
  # The compound labels are one key each rather than the taxonomy's name joined
  # to a lowercased kind, because a locale decides its own word order: "Character
  # tag" and "Etiqueta de personaje" are not the same sentence with a different
  # noun in it.
  module Kinds
    LABEL_KEYS = {
      "universe" => "searches.kinds.universe",
      "story" => "searches.kinds.story",
      "section" => "searches.kinds.section",
      "scene" => "searches.kinds.scene",
      "scene_element" => "searches.kinds.scene_element",
      "character" => "searches.kinds.character",
      "location" => "searches.kinds.location",
      "item" => "searches.kinds.item",
      "event" => "searches.kinds.event",
      "relation" => "searches.kinds.relation",
      "ownership" => "searches.kinds.ownership",
      "tag" => "searches.kinds.tag"
    }.freeze

    # Keyed by the pair the document carries, because that is what the engine
    # stored: `kind` is shared by all eight taxonomies, so the taxonomy is the
    # only thing that tells them apart.
    TAXONOMY_LABEL_KEYS = {
      [ "tag", "Character" ] => "searches.kinds.character_tag",
      [ "tag", "Location" ] => "searches.kinds.location_tag",
      [ "tag", "Item" ] => "searches.kinds.item_tag",
      [ "tag", "Event" ] => "searches.kinds.event_tag",
      [ "tag", "Relation" ] => "searches.kinds.relation_tag",
      [ "tag", "Ownership" ] => "searches.kinds.ownership_tag",
      [ "tag", "Section" ] => "searches.kinds.section_tag",
      [ "tag", "Scene" ] => "searches.kinds.scene_tag"
    }.freeze

    module_function

    def label_for(kind, taxonomy = nil)
      kind = kind.to_s
      # The document's own pair, which is the only thing that can name a taxonomy
      # badge: all eight taxonomies share the `tag` kind.
      pair = [ kind, taxonomy ]
      key = taxonomy.presence && TAXONOMY_LABEL_KEYS[pair]
      return I18n.t(key) if key
      return I18n.t(LABEL_KEYS[kind]) if LABEL_KEYS.key?(kind)

      kind
    end
  end
end
