module StoryInterchange
  # The slices a run writes, in the order it writes them.
  #
  # This list is the whole registry. A new record type adds its class here; the
  # command, the page, and the preview all read the list rather than naming a
  # type themselves, so adding one never means editing those three surfaces.
  # The order also decides which references resolve: a `[[slug]]` becomes a name
  # when a slice in this list owns the target's kind. It also orders the writes
  # themselves: Factions runs before Characters because a Character's
  # `[[faction:slug]]` affiliation becomes a membership of a record that must
  # already exist.
  module Importers
    ALL = [
      Canon,
      Factions,
      Characters,
      Locations,
      Items,
      Stories,
      Sections,
      Scenes,
      Plots
    ].freeze

    # Whether this run writes any record of `kind`. A reference to a kind with no
    # slice is reported rather than resolved, because the record it names does not
    # exist yet.
    def self.written?(kind)
      ALL.any? { |slice| slice.kind == kind }
    end
  end
end
