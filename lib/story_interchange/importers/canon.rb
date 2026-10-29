module StoryInterchange
  module Importers
    # Canon is the first slice: one Canon Rule per `K`/`L`/`D` item.
    #
    # The item's statement and source were parsed by the validator, so this class
    # does not read `universe/canon/` again and cannot disagree with the report
    # about what an item says. An `O` item is reported in `skipped`: an open
    # question is not a rule the prose must obey, so it never becomes a row.
    class Canon < Importer
      slice label_key: "imports.slices.canon_rules", count: :canon_rules

      # The open questions the run will report and never write.
      def self.reported(report)
        report.canon_questions.map(&:id)
      end

      def call
        created = 0
        report.canon_rules.each do |item|
          universe.canon_rules.create!(statement: item.statement, source: item.source)
          created += 1
        end

        Outcome.new(
          label_key: label_key,
          created: created,
          skipped: report.canon_questions.map(&:id)
        )
      end
    end
  end
end
