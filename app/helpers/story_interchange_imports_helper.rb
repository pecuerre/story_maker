module StoryInterchangeImportsHelper
  # How many leftovers one sentence names before it says "and N more". A source
  # may carry hundreds of unmapped sections, and the page has to stay readable.
  NOTE_LIST_LIMIT = 3

  # A record written whole is shown by its name alone, and this answers nil for
  # it. Anything the slice left behind becomes one short sentence naming it,
  # because the operator's question on the preview and the run page is "what is
  # missing from this universe?", not "how many words does this file have?".
  #
  # The notes arrive from the importer grouped by what was left behind, so one
  # kind is one sentence. A record may carry several kinds and therefore several
  # sentences.
  def import_record_notes(record)
    return if record.notes.empty?

    record.notes.group_by(&:kind).map do |kind, notes|
      import_note_sentence(kind, notes.map(&:subject))
    end.join(" ")
  end

  private
    # A row written before notes existed still renders: it was reported, but the
    # stored report kept counts rather than the leftovers themselves, and an
    # unknown kind falls back to the same sentence rather than raising.
    def import_note_sentence(kind, subjects)
      return t("imports.records.notes.introduction") if kind == :introduction
      return t("imports.records.notes.unspecified") if kind == :unspecified

      t("imports.records.notes.#{kind}",
        count: subjects.size,
        subjects: import_note_subjects(subjects),
        default: t("imports.records.notes.unspecified"))
    end

    # The leftovers are quoted and listed. A source with hundreds of unmapped
    # sections gets a bounded list and a counted tail rather than a page-long
    # sentence, the same way `drafts_helper` bounds a tooltip's field names.
    def import_note_subjects(subjects)
      quoted = subjects.map { |subject| t("imports.records.notes.quoted", subject: subject) }
      return quoted.to_sentence if quoted.size <= NOTE_LIST_LIMIT

      t("imports.records.notes.and_more",
        count: quoted.size - NOTE_LIST_LIMIT,
        listed: quoted.first(NOTE_LIST_LIMIT).join(", "))
    end
end
