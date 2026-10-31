module StoryInterchange
  module Importers
    # Canon is the first slice: one Canon Rule per `K`/`L`/`D`/`O` item.
    #
    # The item's identity and prose were parsed by the validator, so this class
    # does not read `universe/canon/` again and cannot disagree with the report
    # about what an item says. The ledger id becomes the slug, its title the name,
    # its prefix the canon type, and its area file the category. An open question
    # is written too, as a rule whose type is `open`, so the workspace can hold it
    # beside the rules it belongs to instead of dropping it from the import.
    class Canon < Importer
      slice label_key: "imports.slices.canon_rules", count: :canon_rules

      class << self
        # Every rule is written whole, so none is reported; the list is still
        # complete, because the page shows the records a run writes.
        def records(report)
          report.canon_rules.map do |item|
            Importer::Record.new(
              name: item.name,
              slug: item.slug,
              sections: 0,
              words: nil,
              reported: false,
              items: []
            )
          end
        end
      end

      def call
        created = report.canon_rules.map do |item|
          universe.canon_rules.create!(
            slug: item.slug,
            name: item.name,
            category: item.category,
            canon_type: item.canon_type,
            statement: item.statement,
            source: item.source
          )
        end

        Outcome.new(label_key: label_key, created: created.size, records: [])
      end
    end
  end
end
