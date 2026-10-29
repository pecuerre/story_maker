module StoryInterchange
  module Importers
    # A Faction is its frontmatter plus the profile answers the source's `##`
    # sections map to. `type`, `home`, `status`, and `backlog` have no Faction
    # column, so they are reported along with the sections the app does not keep
    # (Register, The two rivals, Relationships, Open questions).
    class Factions < Importer
      slice label_key: "imports.slices.factions",
        count: :factions,
        kind: :faction,
        profile: {
          "mission" => :mission,
          "actually for" => :actual_aims,
          "structure" => :structure,
          "internal split" => :internal_divisions,
          "resources" => :resources,
          "would never" => :would_never,
          "would absolutely" => :would_absolutely
        },
        reported_keys: %w[type home status backlog]

      def call
        write_entities(Faction)
      end
    end
  end
end
