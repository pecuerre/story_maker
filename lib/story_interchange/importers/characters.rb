module StoryInterchange
  module Importers
    # A Character keeps the two things its record has columns for: a short
    # summary from `Short summary`, and one Markdown description carrying every
    # other `##` section the source wrote, in source order.
    #
    # The current file keeps only `name`, `slug`, and `affiliation` in
    # frontmatter; role, status, age, occupation, and first appearance are body
    # data under `## Information`, so they stay in the description. `At a glance`
    # is the older summary heading and is still read.
    #
    # The description is stored as written so the app can render its headings,
    # emphasis, lists, and `[[kind:slug]]` links at read time. That is the one
    # profile answer this slice deliberately does **not** resolve into plain
    # names: a link is the meaning, not decoration.
    #
    # `affiliation` is the source's faction list. A `[[faction:slug]]` becomes a
    # Faction membership, and the Factions slice runs first so the record it
    # names exists by then. A bare name such as an in-world institution, or
    # `TBD`, has no Faction record and is reported instead of guessed into one.
    #
    # `role`, `status`, `first_appears`, and `backlog` have no Character column
    # and are reported when they appear in frontmatter.
    class Characters < Importer
      SUMMARY_HEADINGS = [ "short summary", "at a glance" ].freeze
      FACTION_REFERENCE = /\A\[\[faction:([^\[\]]+)\]\]\z/

      slice label_key: "imports.slices.characters",
        count: :characters,
        kind: :character,
        reported_keys: %w[role status first_appears backlog]

      # Nothing in the body is left behind: the identity block and every section
      # land in the description, except the summary. A frontmatter key with no
      # column is reported, and so is an affiliation the source wrote without a
      # Faction link.
      class << self
        # The Faction slugs the affiliation names, in source order. A typed link to
        # anything but a Faction cannot be a membership even though the validator
        # would refuse it, so the kind check keeps this helper safe on its own.
        def faction_slugs(report, entity)
          affiliation_parts(entity).filter_map do |part|
            match = FACTION_REFERENCE.match(part)
            next unless match

            slug = match[1].strip
            slug if report.entity(slug)&.kind == :faction
          end.uniq
        end

        # The affiliation entries that are not Faction links: a bare institution
        # name or `TBD`. They have no record to join, so the import reports them.
        def unlinked_affiliations(report, entity)
          affiliation_parts(entity).reject do |part|
            match = FACTION_REFERENCE.match(part)
            match && report.entity(match[1].strip)&.kind == :faction
          end
        end

        def affiliation_parts(entity)
          entity.frontmatter["affiliation"].to_s.split("·").map(&:strip).reject(&:blank?)
        end

        private
          def reported_entries(report, entity)
            entries = reported_keys.filter_map do |key|
              "#{entity.slug}: #{key}" if entity.frontmatter[key].present?
            end
            entries << "#{entity.slug}: affiliation" if unlinked_affiliations(report, entity).any?
            entries
          end

          # Every section lands in the description, so none is left behind.
          def reported_section_count(_entity)
            0
          end
      end

      def call
        write_entities(Character)
      end

      private
        def attributes_for(entity)
          record_attributes(entity).merge(
            summary: summary_for(entity),
            description: description_for(entity),
            factions: factions_for(entity)
          )
        end

        # Every Faction link in the affiliation becomes one membership. The
        # query is Universe-scoped, so a link can only join a same-Universe
        # Faction.
        def factions_for(entity)
          slugs = self.class.faction_slugs(report, entity)
          return [] if slugs.empty?

          Faction.where(universe: universe, slug: slugs).to_a
        end

        def summary_for(entity)
          section = entity.sections.find { |candidate| SUMMARY_HEADINGS.include?(normalized_heading(candidate.heading)) }
          section && self.class.resolve_references(report, section.body)
        end

        # The source's identity block, then every `##` section except the
        # summary's. References stay in their source form so the details page can
        # turn each one into a link to the record it names.
        def description_for(entity)
          parts = []
          parts << entity.introduction if entity.introduction.present?

          entity.sections.each do |section|
            next if SUMMARY_HEADINGS.include?(normalized_heading(section.heading))

            parts << "## #{section.heading}\n\n#{section.body}"
          end

          parts.join("\n\n").presence
        end

        def normalized_heading(heading)
          heading.to_s.downcase.squish
        end
    end
  end
end
