module StoryInterchange
  # The slices a run writes, in the order it writes them.
  #
  # This list is the whole registry. A new record type adds its class here; the
  # command, the page, and the preview all read the list rather than naming a
  # type themselves, so adding one never means editing those three surfaces.
  # The order also decides which references resolve: a `[[slug]]` becomes a name
  # when a slice in this list owns the target's kind.
  module Importers
    ALL = [
      Canon,
      Characters,
      Factions,
      Locations,
      Items,
      Stories,
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
