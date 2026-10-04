# Reading a remembered change, on a draft's own page, on the page that resolves a
# conflict, and in the lists around it.
#
# A change is the author's *statement of intent*, and this helper's whole job is to
# say what that statement is: which record it is about, what it would do to it,
# and what values it carries. What became of it is a separate fact with a separate
# source — `DraftChangeOutcome`, written by the apply that decided it — and this
# helper reads that too, but only where one exists. It does not infer an outcome
# from a version stamp: only the apply can know, and a page that guessed would be
# reporting a second answer about the same record (ADR 0019, ADR 0024).
#
# The same reading answers three kinds of page. A draft's own page prints a change;
# a list workspace has to say what the same change would do to *its* rows — a
# remembered create appears in the list it would have joined, a remembered edit
# and delete badge the record that is still there; and the conflict page prints
# the change *beside the record as it stands now*, which is the only way an author
# can choose between them. All three are answers about one reader's one open
# draft, so all three are read through one `DraftPreview`, built once per request.
#
# Three shapes need reading rather than printing:
#
# * **A record type** is named with the same word a search result badge uses
#   (`Search::Kinds`), so a Character is called a character here and in the
#   dropdown. Three content models are not search documents at all — a Scene's
#   three presence links — and `searches.kinds` deliberately does not name them,
#   so `drafts.kinds` names exactly those three.
# * **A submitted id list** — a tag assignment, or a Dialogue's speakers — is ids,
#   which means nothing to a reader. Every one of them is a collection writer on
#   the model, so the names are one association hop from the key the form sent
#   (`character_tag_ids` → `character_tags`, `character_ids` → `characters`), and
#   the row can print what the change is actually about. It is labelled by that
#   association as well, because "Character tags" is the word the editor sees
#   everywhere else and `character_tag_ids` is a name nobody uses.
# * **A photo** is stored as a `data:` URL and removed by a boolean. Printing
#   either would put a base64 blob or a bare `0` on the page, so both are stated.
module DraftsHelper
  # **What a closed draft's history says**, as one line: when it stopped being
  # actionable, and what the run that closed it did to its changes.
  #
  # Both surfaces that read a closed draft read it from here — the row in the
  # drafts list and the summary on the draft's own page — because they are one
  # fact about one draft, and two compositions of it is how a list and a page
  # come to disagree about what an apply did (ADR 0024).
  #
  # The counts come from the draft's own columns rather than from its outcome rows:
  # the list prints one sentence for every row it renders, and a row that had to
  # group the outcome table first would be the one list in the application that
  # resolves per row. The rows themselves are what a draft's page draws per change,
  # so both are stored by the same run in the same transaction.
  #
  # Nothing is said about a draft that is still open, and nothing about the
  # remembered values — those are the draft's own page, one row per change. This is
  # the moment and the tally, and it is empty rather than speculative for a draft
  # whose closure left nothing to report.
  def draft_history_sentence(draft)
    sentences = [ draft_closure_sentence(draft) ]
    sentences += draft_apply_count_sentences(draft) if draft.closed?

    safe_join(sentences.compact, " ")
  end

  # What one change's own row says about what became of it: the badge that names
  # the state, and the sentence that says why — or nil when the draft has not been
  # applied yet, because an open change has no outcome and a badge guessing at one
  # would be the second answer this page used to be careful not to give.
  #
  # A change the author answered `"theirs"` is badged as that rather than as the
  # conflict that put it there, because the two are different outcomes: one was
  # refused, the other was decided. The badge key is therefore the outcome's own
  # vocabulary, and `kept` is the one state that is not a reason.
  def draft_change_outcome_badge(outcome)
    t("drafts.outcomes.badge.#{outcome.kept? ? :kept : outcome.state}")
  end

  # Why a change was not written, or nil when it was — a written change needs no
  # explanation, and its badge already says so. The sentence is what makes a
  # skipped row actionable: it names the one thing the author can still do about
  # it, which is redo it from the record's own page.
  def draft_change_outcome_reason(outcome)
    return if outcome.written?

    t("drafts.outcomes.reason.#{outcome.kept? ? :kept : outcome.state}")
  end

  # This request's reader's view of their own open draft, built once.
  #
  # It is memoized on the view rather than fetched per call because the same three
  # answers are asked by the right sidebar, by every list workspace, and by each
  # row of those lists — and `Draft.open_for` is a query. The memoization lives
  # for one request and dies with the view, which is the same lifetime `Current`
  # itself has: nothing here is ever read on a later request.
  def draft_preview
    return @draft_preview if defined?(@draft_preview)

    @draft_preview = DraftPreview.new(user: Current.user, universe: Current.universe)
  end

  # What a row should say about a record, as one of three badge states: `:draft`
  # for a record a remembered create would have made, `:edit`, `:deletion`, or nil
  # when the row has nothing pending on it.
  #
  # **An unsaved record is `:draft` by construction.** Nothing else puts one in a
  # list: `DraftPreview#creates_for` is the only source of them, and it builds them
  # for exactly this purpose. The badge partial therefore takes the state rather
  # than the record, so a row and a pending row read it the same way.
  def draft_pending_state(record)
    return :draft if record.present? && record.new_record?

    draft_preview.state_for(record)
  end

  # The records this draft would have added to `model`'s list, as unsaved
  # instances. Empty in a `direct` universe, for a guest, and for a model nobody
  # has remembered a create of, so a workspace can call it unconditionally.
  def draft_pending_creates_for(model)
    draft_preview.creates_for(model)
  end

  # The records a taxonomy tree's remembered creates would have added, resolved
  # from the tree's own `model_param` (`"character_tag"` → `CharacterTag`).
  #
  # `RecordTarget.model_for` is the gate, so a `model_param` names a content class
  # or nothing — the tree is rendered from a fixed set of workspaces, and a param
  # that named something else would find no pending rows rather than a constant.
  def draft_pending_taxonomy_creates(model_param)
    model = RecordTarget.model_for(model_param.to_s.camelize)

    model ? draft_pending_creates_for(model) : []
  end

  # What a change's row calls itself: the record's own label when the change names
  # one that is still there, and the type it would create when it does not.
  #
  # `record` is passed in rather than resolved here because the row needs the same
  # answer twice — to decide whether to link and to write the link — and
  # `DraftChange#resolved_record` deliberately does not remember its answer, so a
  # second call would be a second query and could disagree if the record changed
  # between them.
  def draft_change_subject(change, record)
    return t("drafts.show.new_record", kind: draft_change_kind(change)) if record.nil?

    record_label(record)
  end

  # What a **pending row** calls itself: the record's own label where it has one to
  # give, and otherwise the type the change would create — the same sentence
  # `draft_change_subject` gives a remembered create on a draft's page and in the
  # sidebar panel.
  #
  # The fallback is what a change's payload cannot supply is for. A remembered
  # create is built straight from the payload without being validated (ADR 0020),
  # so it can be a record the universe would refuse: an Event with no title and no
  # dates has no label of its own and `Event#display_label`'s last rung is a
  # phrase about an id it does not have, and a nameless Character has no label at
  # all. Printing either would put a row in a list that reads as a stored record —
  # or as a row with no subject — for something that does not exist and may never
  # be written.
  #
  # **This asks the model, rather than re-deriving the label's ladder.** `Event`
  # publishes `#identifiable?` for exactly this question, because "can this record
  # call itself?" is the model's own rule and a view that answered it by comparing
  # a rendered string against a translated fallback would be a second copy of the
  # ladder that could drift from the first.
  #
  # Nothing here validates the record or withholds the row: whether the applier
  # will accept a remembered create is not knowable before the apply, and a stored
  # outcome records what the apply decided rather than predicting it (ADR 0024),
  # so the row does not claim to be one. It says what the change would create and
  # leaves the decision to the apply, which is where the model's own validations
  # are authoritative.
  def draft_pending_record_label(record)
    label = record_label(record)
    return label if label.present? && draft_identifiable?(record)

    t("drafts.show.new_record", kind: draft_record_kind(record.class.name))
  end

  # The word for the record type a change names, whether or not the record is
  # still there: a change about a record somebody else has since deleted still
  # has to say what it was about.
  def draft_change_kind(change)
    draft_record_kind(change.record_type)
  end

  # The word for a record type, derived once from the content registry and the
  # search declarations rather than listed per workspace.
  def draft_record_kind(record_type)
    model = RecordTarget.model_for(record_type)
    return t("drafts.kinds.unknown") if model.nil?

    declaration = model.searchable? ? model.search_declaration : nil
    return t("drafts.kinds.#{model.model_name.param}") if declaration.nil?

    Search::Kinds.label_for(declaration.kind, declaration.taxonomy)
  end

  # The remembered attributes, as `[ label, value ]` pairs, in the order the
  # payload stores them.
  #
  # The scope column is dropped: it is the column that placed the record in its
  # universe, story, or scene, and this page is already inside that universe — a
  # bare `story_id` is a number the reader cannot name. Everything else is kept,
  # including the values a column does not hold, because a tag list or a photo is
  # the part of the change that `record.changes` would have dropped.
  def draft_change_attributes(change)
    return [] if change.payload.blank?

    model = RecordTarget.model_for(change.record_type)

    change.payload.filter_map do |name, value|
      next if name == change.scope_attribute

      association = id_list_association(model, name)
      [ draft_change_label(model, name, association), draft_change_value(model, name, value, association) ]
    end
  end

  # The record's side of one conflict, as the same `[ label, value ]` pairs the
  # change's own half prints — so "your change" and "theirs" are two columns of
  # the same rows and the reader compares them line against line.
  #
  # Only what the record can actually answer is listed. A field is dropped when
  # it is not an attribute the model has or an id list it has a collection for,
  # which is what keeps the two photo writers (`photo_data`, `remove_photo` —
  # form fields with no reader) from printing an object description, and what
  # keeps a payload naming a column nobody has from raising here: the page is
  # showing a *conflict*, not re-running the applier's write.
  #
  # An empty answer is the honest one for a remembered delete, which carries no
  # payload at all: there is no field the record is being asked about, and the
  # page says the record simply stays instead of printing an empty column.
  def draft_conflict_current_attributes(report)
    change = report.change
    return [] if change.payload.blank? || report.record.nil?

    model = RecordTarget.model_for(change.record_type)
    record = report.record

    change.payload.filter_map do |name, _value|
      next if name == change.scope_attribute
      next if model.blank? || !record.respond_to?(name)
      next unless model.column_names.include?(name) || id_list_association(model, name)

      association = id_list_association(model, name)
      [ draft_change_label(model, name, association), draft_change_value(model, name, record.public_send(name), association) ]
    end
  end

  # What the two buttons do, for the conflict this row is asking about. There are
  # three answers rather than one because there are three different decisions:
  # overwriting a record that moved, bringing back a record somebody deleted, and
  # deleting a record that moved underneath the author. A sentence that described
  # all three would be wrong on two of them, which is worse than saying nothing.
  def draft_conflict_choice(report)
    return t("drafts.conflicts.choose.deleted") if report.state == :deleted

    t("drafts.conflicts.choose.#{report.change.deleting? ? :removed : :moved}")
  end

  private
    # When this draft stopped being actionable, as a sentence named by its own
    # status: `Applied …` and `Discarded …` are different facts and `status` is
    # what tells them apart, so the keys are the statuses rather than two more
    # booleans on the model.
    #
    # It is nil for an open draft — there is no moment yet — and the `_html` suffix
    # is what lets the moment be a `<time>` element with the machine-readable
    # attribute beside the readable one, which is the same shape the row's
    # "remembered at" line already uses.
    def draft_closure_sentence(draft)
      return if draft.open? || draft.closed_at.blank?

      t("drafts.history.#{draft.status}_html",
        at: time_tag(draft.closed_at, l(draft.closed_at, format: :short)))
    end

    # What the run did, in as many sentences as there are distinct outcomes — up to
    # three, and they stay separate for the reason the flash's sentences do: a
    # change dropped on purpose was not skipped, so folding the kept count into
    # either of the others would report the run as failed when the author simply
    # decided.
    #
    # The fourth sentence is the absence of all three. It is not "0 changes are
    # live" — a run that wrote nothing is a fact worth stating plainly, and it is
    # the sentence a discarded draft gets as well as an applied one with nothing in
    # it.
    def draft_apply_count_sentences(draft)
      sentences = []
      sentences << t("drafts.history.live", count: draft.applied_count) if draft.applied_count.positive?
      sentences << t("drafts.history.not_applied", count: draft.skipped_count) if draft.skipped_count.positive?
      sentences << t("drafts.history.kept", count: draft.kept_count) if draft.kept_count.positive?
      sentences << t("drafts.history.nothing_written") if sentences.empty?

      sentences
    end

    # Whether the model can name this record at all. A model that has its own rule
    # for the question publishes it (`Event#identifiable?`), and a model that does
    # not is answerable by its own label — every other model's label *is* its name
    # or its endpoints, so a blank label is the whole answer.
    def draft_identifiable?(record)
      record.respond_to?(:identifiable?) ? record.identifiable? : true
    end

    # The attribute's own name, resolved the way every form label and every
    # `errors.format` sentence in this application resolves it. A column the
    # locale has not named falls back to a humanized English name, which is the
    # documented behaviour of `human_attribute_name` rather than a second
    # vocabulary kept here.
    #
    # A submitted id list is labelled by the collection it fills rather than by the
    # writer that submitted it: the editor sees "Character tags" everywhere else
    # and has no idea what a `character_tag_ids` is, and the association is the
    # same word the field's own name already is minus the `_ids`.
    def draft_change_label(model, name, association)
      field = association ? association.name : name

      model&.human_attribute_name(field) || field.humanize
    end

    # One remembered value, as the reader should see it. `nil` never reaches the
    # page as a blank cell, because a blank value is a state worth naming and
    # `shared.detail_fact.blank` is this application's one answer to it.
    def draft_change_value(model, name, value, association)
      return association_names(association, value) if association.present?
      return t("drafts.attributes.photo") if name == "photo_data"
      return t("drafts.attributes.photo_removed") if name == "remove_photo" && truthy?(value)
      return value.to_sentence if value.is_a?(Array)

      value.presence || t("shared.detail_fact.blank")
    end

    # A submitted id list the model has a collection for: a tag assignment, or a
    # Dialogue's speakers. The association is derived from the key rather than
    # listed, because the key a form submits and the collection it fills have the
    # same name in every case this application has.
    def id_list_association(model, name)
      return if model.blank? || !name.end_with?("_ids")

      model.reflect_on_association(name.delete_suffix("_ids").pluralize)
    end

    # The names behind the ids, in the order the author submitted them, joined in
    # the reader's language — `to_sentence` reads `support.array`, which both
    # locale files carry. An id that no longer resolves is dropped rather than
    # printed: it names nothing, and the change it was part of is the author's
    # statement about the ids that are still there.
    def association_names(association, value)
      names = Array(value).filter_map { |id| association.klass.find_by(id: id) }.map { |record| record_label(record) }

      names.to_sentence.presence || t("shared.detail_fact.blank")
    end

    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value).present?
    end
end
