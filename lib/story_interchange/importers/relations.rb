module StoryInterchange
  module Importers
    # A Character's `## Relationships` bullets become Relations between the
    # Characters they name, and the types those bullets carry become the
    # Universe's Relation tags.
    #
    # A bullet leads with the linked Character:
    # `[[character:slug|type:boss]] - the dynamic.` The slug is everything before
    # the `|`; the type names the linked Character's role toward the file's own
    # Character. The type is optional: `[[character:slug]]` and
    # `[[character:slug|type:]]` both mean one with no type.
    #
    # **One Relation per unordered pair.** The source writes the same
    # relationship from both ends, so the reciprocal bullet would otherwise
    # create a second edge. The first bullet decides the pair's type where one
    # exists; a later typed bullet replaces an earlier untyped one so the source
    # does not lose a type it did state. A bullet with no type becomes an
    # untagged Relation rather than being dropped.
    #
    # **The type becomes a Relation tag with that exact name**, created when the
    # Universe does not already have it. Every type the source states is created,
    # including one that only appears on a reciprocal bullet that did not win the
    # pair. The source defines no inverse, so a created tag keeps the model's
    # symmetric default.
    #
    # The bullet's dynamic and its `Leverage:` line have no separate column, so
    # they become the Relation's description together. References are resolved to
    # record names and canon/rule ids, because a Relation's description is plain
    # text rather than a rendered profile.
    class Relations < Importer
      slice label_key: "imports.slices.relations", count: :relations

      RELATIONSHIPS_HEADING = "relationships"
      BULLET = /\A-[ \t]+/
      LEADING_CHARACTER = /\A\[\[character:(?<slug>[^|\[\]\n]+)(?:\|type:(?<type>[^\[\]\n]*))?\]\]/
      SEPARATOR = /\A[ \t]*[-–—][ \t]*/
      LEVERAGE = /\A[ \t]*Leverage:[ \t]*/i

      # One relationship as the source states it. `from` is the file's own
      # Character and `to` is the linked one. The type names `to`'s role toward
      # `from`; the Relation stores the typed edge with `to` first so the tag
      # reads as a verb about the first endpoint.
      Edge = Data.define(:from, :to, :type, :description) do
        def character_one = type.present? ? to : from
        def character_two = type.present? ? from : to
      end

      class << self
        # What the import will write, shown before anything is created.
        def preview(report)
          edges(report).size
        end

        # Every Relation the run writes, in source order.
        def records(report)
          characters = report.entities(:character).to_h { |entity| [ entity.slug, entity.name ] }

          edges(report).map do |edge|
            first = characters.fetch(edge.character_one)
            second = characters.fetch(edge.character_two)
            label = edge.type.present? ? "#{first} — #{edge.type} → #{second}" : "#{first} → #{second}"
            Importer::Record.new(name: label, slug: "#{edge.character_one}-#{edge.character_two}", notes: [])
          end
        end

        # Every edge the source states, before reciprocal bullets are collapsed.
        def parsed_edges(report)
          report.entities(:character).flat_map { |entity| edges_for(report, entity) }
        end

        # One edge per unordered pair. A typed edge wins over an untyped one, so
        # a reciprocal bullet cannot hide the type the source did write.
        def edges(report)
          parsed_edges(report).each_with_object({}) do |edge, chosen|
            next if edge.from == edge.to

            key = [ edge.from, edge.to ].sort
            current = chosen[key]
            chosen[key] = edge if current.nil? || (current.type.nil? && edge.type.present?)
          end.values
        end

        # Every nonblank type the source states, in first-seen order. The slice
        # creates a tag for each one, not only for the types that survive the
        # reciprocal collapse.
        def types(report)
          parsed_edges(report).filter_map(&:type).uniq
        end

        private
          def edges_for(report, entity)
            section = entity.sections.find do |candidate|
              candidate.heading.to_s.downcase.squish == RELATIONSHIPS_HEADING
            end
            return [] unless section

            bullets(section.body).filter_map do |lines|
              edge_for(report, entity, lines)
            end
          end

          # A bullet is a column-zero `-` line and every indented line beneath it.
          # A non-bullet relationship (a plain name or a faction) has no
          # Character to link, so it is not an edge this slice can write.
          def bullets(body)
            collected = []
            current = nil

            body.to_s.each_line do |line|
              if BULLET.match?(line)
                collected << current if current
                current = [ line ]
              elsif current
                current << line
              end
            end

            collected << current if current
            collected
          end

          def edge_for(report, entity, lines)
            first = lines.first.to_s.sub(BULLET, "")
            match = LEADING_CHARACTER.match(first)
            return unless match

            to = match[:slug].strip
            return unless report.entity(to)&.kind == :character

            Edge.new(
              from: entity.slug,
              to: to,
              type: match[:type].to_s.strip.presence,
              description: description_for(report, lines, match.post_match)
            )
          end

          # The dynamic and the optional `Leverage:` paragraph. The source's
          # canon and rule links become their bare ids because this description
          # is plain text, not the rendered Markdown a Character profile keeps.
          def description_for(report, lines, first_remainder)
            remainder = [ first_remainder.sub(SEPARATOR, ""), *lines.drop(1) ].map(&:rstrip)
            leverage = remainder.index { |line| LEVERAGE.match?(line) }

            dynamic_lines = leverage ? remainder[0...leverage] : remainder
            leverage_lines = leverage ? remainder[leverage..] : []

            dynamic = text(report, dynamic_lines.join("\n").strip)
            limit = text(report, leverage_lines.map(&:strip).reject(&:empty?).join(" ")
              .sub(LEVERAGE, ""))

            [ dynamic.presence, ("Leverage: #{limit}" if limit.present?) ].compact.join("\n\n").presence
          end

          def text(report, value)
            resolve_references(report, value).gsub(/\[\[(?:canon|rule):([^\[\]\n]+)\]\]/, '\1')
          end
      end

      def call
        tags = self.class.types(report).to_h do |type|
          [ type, universe.relation_tags.find_or_create_by!(name: type) ]
        end

        created = self.class.edges(report).map do |edge|
          Relation.create!(
            universe: universe,
            character1: universe.characters.find_by!(slug: edge.character_one),
            character2: universe.characters.find_by!(slug: edge.character_two),
            relation_tags: edge.type.present? ? [ tags.fetch(edge.type) ] : [],
            description: edge.description
          )
        end

        Outcome.new(label_key: label_key, created: created.size, records: self.class.records(report))
      end
    end
  end
end
