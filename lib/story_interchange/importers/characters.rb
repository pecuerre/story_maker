module StoryInterchange
  module Importers
    # A Character is its frontmatter plus the profile answers the source's `##`
    # sections map to. `role`, `affiliation`, `status`, `first_appears`, and
    # `backlog` have no Character column: they are reported, and so are the
    # sections the app keeps in another record kind (State of knowledge,
    # Relationships) or not at all (Voice, Arc, Open questions).
    #
    # `affiliation` never becomes Faction membership here. It is free text in the
    # real source and may name a Faction, another record, or prose, so the
    # operator assigns membership in the app rather than the import guessing.
    class Characters < Importer
      slice label_key: "imports.slices.characters",
        count: :characters,
        kind: :character,
        profile: {
          "at a glance" => :at_a_glance,
          "wants" => :wants,
          "needs" => :needs,
          "contradictions" => :contradictions,
          "under pressure they" => :under_pressure_they,
          "never" => :never
        },
        heading_prefixes: { "lies about" => :lies_to_self },
        reported_keys: %w[role affiliation status first_appears backlog]

      def call
        write_entities(Character)
      end
    end
  end
end
