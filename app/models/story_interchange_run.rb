# One completed story-interchange import, and the answer it gave.
#
# **It exists because that answer is too large for a flash.** A source with a few
# hundred reported ids builds a message bigger than the 4 KB a session cookie may
# hold, and the cookie store raises `ActionDispatch::Cookies::CookieOverflow` while the
# response commits — after the import transaction has already succeeded. The run row is
# written inside that transaction, so a refused or failed run leaves neither and a
# committed run always has its page.
#
# **The universe is copied in, not referenced** (see the migration). A later run
# replaces or soft-deletes the universe this one created, and the page still has to say
# what this run wrote. The page links to a live universe by slug when one still exists
# and otherwise prints the stored name alone, which is the reason there is no foreign
# key to `universes`.
#
# `outcomes` is the same data `Importers::Importer::Outcome` returns to the preview and
# the task: one entry per slice, with the records that slice reported instead of
# writing. `slices` is the reader that gives those entries named methods, so a view is
# not indexing a JSON hash by hand.
#
# **This is not content and has no `Ability` rule.** A run's page asks the same
# platform question the import page does (`:manage` on `StoryInterchange::Import`), so
# there is no per-row authorization: every platform admin may read every run.
class StoryInterchangeRun < ApplicationRecord
  # One slice's answer, read back from `outcomes`. `reported` names the records
  # the slice left partly unwritten, with the counts the page shows.
  Slice = Data.define(:label_key, :created, :reported) do
    def reported? = reported.any?
  end

  belongs_to :user

  validates :source, :universe_name, :universe_slug, presence: true
  validates :outcomes, presence: true

  # Writes the row the import's transaction commits with. `outcomes` are the live
  # `Outcome` values the slices returned, converted once here rather than by every
  # caller.
  def self.record!(universe:, replaced:, outcomes:, operator:, source:)
    create!(
      user: operator,
      source: source,
      universe_name: universe.name,
      universe_slug: universe.slug,
      replaced: replaced,
      outcomes: outcomes.map do |outcome|
        {
          "label_key" => outcome.label_key,
          "created" => outcome.created,
          "reported" => outcome.reported.map do |record|
            {
              "name" => record.name,
              "slug" => record.slug,
              "sections" => record.sections,
              "words" => record.words
            }
          end
        }
      end
    )
  end

  def slices
    outcomes.map do |outcome|
      Slice.new(
        label_key: outcome["label_key"],
        created: outcome["created"],
        reported: reported_from(outcome)
      )
    end
  end

  def reported?
    slices.any?(&:reported?)
  end

  private
    # The page needs a record's name and two counts, not the detailed list of
    # source items it used to store. A row written before the counts existed still
    # renders: its strings are grouped back under the record its prefix names.
    def reported_from(outcome)
      if outcome.key?("reported")
        outcome["reported"].map { |record| record_from(record) }
      else
        legacy_records(outcome["skipped"])
      end
    end

    def record_from(record)
      StoryInterchange::Importer::Reported.new(
        name: record["name"],
        slug: record["slug"],
        sections: (record["sections"] || 0).to_i,
        words: record["words"],
        items: []
      )
    end

    def legacy_records(items)
      Array(items).group_by { |item| item.split(": ", 2).first }.map do |slug, grouped|
        StoryInterchange::Importer::Reported.new(name: nil, slug: slug, sections: 0, words: nil, items: grouped)
      end
    end
end
