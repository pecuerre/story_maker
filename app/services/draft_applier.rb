# Writes one author's remembered changes into the universe.
#
# ADR 0019 settled the rule this service exists to keep: **an applier must not
# write records directly.** Where a controller routes a mutation through a
# service — every ordered and hierarchical collection goes through
# `PositionedResourceOrder` — the applier routes it through the same service, and
# the model's own validations still run. A direct `record.update(attributes)`
# would skip sibling-position normalization, skip the tag-scope validation, and
# leave the soft-delete cascades and the search reindex to chance.
#
# Two facts are derived rather than listed, which is what keeps the applier and
# the controllers from drifting apart:
#
# * **Which collection a record's siblings live in.** The owner association
#   `UniverseScopeResolver` walks — `story`, `scene`, `section` — or the universe
#   itself, read from the record's own columns. That is exactly what every
#   positioned controller's `sibling_collection` and
#   `sibling_position_scope_owner` return: `@story.sections` for a Section,
#   `@scene.scene_elements` for an Element, `Current.universe.characters` for a
#   Character.
# * **Whether a write is ordered at all.** A model with a `position` column is
#   one whose collection `PositionedResourceOrder` maintains, and a model with a
#   `parent_id` is one whose siblings are scoped by it. A Relation, an Ownership,
#   and a Scene's three presence links have neither, and their controllers
#   declare no ordering, so they are written the way their own controller writes
#   them: `save`, `update`, `soft_delete`.
#
#   A derivation is only as good as the guard on it, so
#   `test/services/draft_applier_test.rb` holds it against every controller that
#   declares itself positioned. A new ordered controller that adds a `position`
#   column without being listed there fails the suite naming the controller,
#   rather than being applied with a plain `save` that leaves a gap in the
#   sequence.
#
# **What a change that cannot be written is.** `DraftConflictDetector` owns that
# question — it compares the version a change was remembered against with the
# record's version now, counts an unknown base as moved, and tells a record that
# has been soft-deleted from one that was never there. This service asks it rather
# than repeating the comparison, so the apply's skip decision and the resolution
# page's list of conflicts cannot disagree. A change whose record is gone, a change
# the universe cannot place, and a change the live path refuses are each reported
# in the result and none of them is written; a change that has moved is reported
# too, unless the author has answered it (below).
#
# **The reasons are named, and there are five.** `:moved` and `:deleted` are the
# two conflicts; `:missing` is a record that does not resolve at all; `:gone` is a
# delete whose record somebody has already deleted, which is reported as skipped
# rather than claimed as written — nothing was written, and the author's intent
# already holds, so the honest answer is the one the draft's page can print. The
# apply still closes its draft in every one of those cases (below), and the flash
# that follows reports what was written and what was not.
#
# **An author can answer a conflict, and the answer arrives with the apply.**
# `DraftsController#apply` shows the conflicts it finds rather than writing them,
# and comes back with one answer per change under `answers` — `"mine"` writes the
# remembered values over what is there now, `"theirs"` leaves the record alone and
# discards the change. Two consequences of that shape are deliberate:
#
# * **The answer is not stored anywhere.** It travels with the apply that uses it,
#   and the whole run is one transaction, so an apply that fails leaves a draft
#   with nothing written and no answer half-recorded. A remembered change is
#   append-only (ADR 0019), and an answer is not a statement about what the author
#   observed — it is a decision about this run, so it belongs to this run.
# * **An unanswered conflict is still reported, not written.** Called without
#   answers — which is how `test/services/draft_applier_test.rb` calls it, and how
#   a future reviewer action may — this service behaves exactly as it did before
#   the resolution page existed. The conservative direction is inherited from
#   `VersionStamp`: a conflict an author can see is recoverable, a silently
#   overwritten edit is not.
#
# What the run decided is in `Result#answered`, keyed by change id, so a caller
# can tell a change the author *chose* to drop from one this service refused.
#
# **The draft is closed whatever the outcome.** Applying twice is the one failure
# this must not have: a remembered `create` names no record, so a second apply
# would write the author a second copy of it, and `PositionedResourceOrder` would
# happily place it. `Draft#open?` is therefore the precondition for calling
# `#apply` at all, and every run ends by moving the draft to `applied`. A change
# that was skipped is still listed on the draft's own page, so the author can see
# what it said and redo it from the record's own page.
class DraftApplier
  # The five states a change can be left in when it is not written, named once so
  # a test asserts the vocabulary rather than a symbol spelled out at the call site.
  # `:unplaceable` and `:refused` are this service's own two answers — a create
  # whose stored scope does not place it here, and a write the live path declined —
  # and the other three are `DraftConflictDetector::Report` states. A change the
  # author answered `"theirs"` is reported under the same states, because the
  # reason it was not written is still the conflict; `Outcome#answer` is what says
  # it was a decision rather than a refusal.
  SKIP_REASONS = %i[moved deleted missing gone unplaceable refused].freeze

  # The two answers the resolution page offers, and the only two values a caller
  # may hand this service for a conflicting change. They are the vocabulary the
  # page's buttons, the controller's params, and this service's `Outcome#answer`
  # all share, so a third word cannot arrive from one of them alone.
  ANSWERS = %w[mine theirs].freeze

  # What one change's application did: `reason` is nil when the change was
  # written, and otherwise why it was not. `answer` is the author's choice when
  # the change was in conflict and they made one, and nil otherwise — which is
  # what tells a change dropped on purpose (`"theirs"`) apart from one this
  # service refused, since neither is written and both would otherwise be a
  # skipped row with a reason on it.
  Outcome = Data.define(:change, :reason, :answer) do
    def written?
      reason.nil?
    end

    # A change the author answered `"theirs"`: the record keeps what is there and
    # the remembered change is dropped. It is not written, and it is not a
    # failure either, so it is reported in its own half of the summary.
    def kept?
      answer == "theirs"
    end
  end

  # The summary an apply returns. `applied` and `skipped` are the two halves the
  # caller needs, `answered` is what an author's choices were, and `complete?` is
  # the only question the controller asks about the first two.
  #
  # `skipped` holds only what was not written *and* not decided: a change the
  # author answered `"theirs"` is in `answered`, not here, so `complete?` reads as
  # "nothing was left unexplained" rather than "nothing was dropped".
  Result = Data.define(:applied, :skipped, :answered) do
    def applied_count
      applied.size
    end

    def skipped_count
      skipped.size
    end

    # The conflicts the author decided, as `{ change.id => "mine" | "theirs" }`.
    def answered_count
      answered.size
    end

    # How many of those left the record as it stands, which is the sentence the
    # flash adds after the counts.
    def kept_count
      answered.count { |_change_id, answer| answer == "theirs" }
    end

    def complete?
      skipped.empty?
    end
  end

  # `answers` is the author's choice per conflicting change, keyed by change id
  # and valued with one of `ANSWERS`. It is not persisted: it arrives with the
  # apply that uses it and is dropped with that request.
  def initialize(draft, answers: {})
    @draft = draft
    @answers = normalize_answers(answers)
    @detector = DraftConflictDetector.new(draft)
  end

  # Whether a model's writes go through the ordering service, and whether its
  # siblings are scoped by a parent.
  #
  # Both are read from the model's own columns rather than kept in a list here,
  # because a list would be a second thing to keep in step with the twenty
  # controllers that declare their own ordering. They are public because that
  # derivation is a contract with those controllers, and the test that holds it —
  # `test/services/draft_applier_test.rb`, which walks every routed controller
  # rather than a list of its own — should not have to reach into a private method
  # to do it.
  def self.ordered?(model)
    model.column_names.include?("position")
  end

  def self.hierarchical?(model)
    model.column_names.include?("parent_id")
  end

  # Applies every change the universe can still write, in the order the changes
  # were remembered, and closes the draft.
  #
  # The run is one transaction, and the draft's own status change is inside it.
  # A skipped change is not an error — it is reported and the rest of the draft is
  # still written — but an *unexpected* failure half way through must not leave a
  # draft that is still open over a universe that is already partly written, since
  # applying it again would duplicate every create it had already applied.
  #
  # An answered conflict is decided here rather than before the run: `"mine"` is
  # written with the rest, `"theirs"` is dropped from `skipped` into `answered`,
  # and either way the draft closes with the same status change as everything else.
  def apply
    outcomes = []

    ApplicationRecord.transaction do
      @draft.draft_changes.each { |change| outcomes << apply_change(change) }
      @draft.update!(status: "applied")
    end

    Result.new(
      applied: outcomes.select(&:written?).map(&:change),
      skipped: outcomes.reject { |outcome| outcome.written? || outcome.kept? },
      answered: outcomes.filter_map { |outcome| [ outcome.change.id, outcome.answer ] if outcome.answer }.to_h
    )
  end

  private
    def apply_change(change)
      report = @detector.report_for(change)
      answer = report.conflict? ? answer_for(change) : nil

      reason =
        case change.action
        when "create" then create(change)
        when "update" then update(report, change, answer)
        else delete(report, change, answer)
        end

      Outcome.new(change, reason, answer)
    end

    # A remembered create names no record, so the payload's own scope column is
    # the only thing that says where the record goes. It is resolved here rather
    # than trusted: the column is written by a controller that already
    # authorized the universe, but it is stored data read back days later, and an
    # id that is not this universe's own story is not a scope at all. A create
    # that cannot be placed is reported, never guessed at.
    def create(change)
      model = model_for(change)
      owner = scope_owner_from_payload(model, change)
      return :unplaceable if owner.nil?

      resource = owner.public_send(collection_name(model)).new(change.payload.symbolize_keys)

      write(create_resource(resource, model)) ? nil : :refused
    end

    # The detector's answer is the precondition: a change it does not call
    # writable is reported under its own state and nothing is written — unless the
    # author has answered the conflict, which is the one thing that may write over
    # a record that has moved or bring back one somebody has deleted. An answer is
    # only ever consulted for a conflict, so a state that is not a choice (`:missing`
    # here, `:gone` in `delete`) reaches this method with none.
    def update(report, change, answer)
      return report.state unless report.writable? || answer == "mine"

      write(update_resource(report.record, update_attributes(report, change))) ? nil : :refused
    end

    # A delete answered `"mine"` removes a record somebody else has edited since:
    # what changed underneath is not a reason to keep something the author meant to
    # remove. A delete whose record is already gone is not a conflict, so it never
    # gets an answer and is still reported as `:gone` — nothing to write, and the
    # author's intent already holds.
    def delete(report, change, answer)
      return report.state unless report.writable? || answer == "mine"

      delete_resource(report.record)

      nil
    end

    # What "apply mine" writes onto an update's record: the remembered payload,
    # and for a record somebody has deleted, the clearing of `deleted_at` beside
    # it.
    #
    # **Restoring is folded into the same write rather than done first.** The two
    # answered together is what makes the answer atomic: `restore` runs with
    # `validate: false`, so restoring first and then writing the payload would
    # resurrect a record the live path then refused, leaving the author's answer
    # half-made — a record that came back carrying the values they did not get to
    # write. Here the model's own validations decide both halves in one `save`,
    # and a refusal leaves the record exactly as somebody else left it.
    #
    # **A restored ordered record is put back where it sat.** `PositionedResourceOrder#destroy`
    # renumbers the siblings it leaves behind when a record goes, so the deleted
    # row's own `position` is now a number inside a sequence that no longer has a
    # gap — and handing that number to `PositionedResourceOrder#update` as a
    # requested position re-inserts the record at that index and renumbers the
    # rest, which is the one way to bring it back without a duplicate position in
    # the middle of the sequence.
    def update_attributes(report, change)
      attributes = change.payload.symbolize_keys
      return attributes unless report.state == :deleted

      attributes[:deleted_at] = nil
      if attributes[:position].nil? && positioned?(report.record.class) && report.record.position.present?
        attributes[:position] = report.record.position
      end

      attributes
    end

    # The author's answer for one change, if they made one. Both halves of the
    # filtering happen: the controller drops anything that is not one of
    # `ANSWERS`, and this service drops anything that is not an answer for a
    # change it is actually applying — an answer is an instruction to write over
    # somebody else's record, so neither half may be skipped because the other
    # looked safe.
    def answer_for(change)
      @answers[change.id.to_s]
    end

    def normalize_answers(answers)
      return {} if answers.blank?

      source = answers.respond_to?(:to_unsafe_h) ? answers.to_unsafe_h : answers.to_h

      source.each_with_object({}) do |(change_id, answer), normalized|
        normalized[change_id.to_s] = answer.to_s if ANSWERS.include?(answer.to_s)
      end
    end

    # The ordered collection's own write, or the plain one. `position` is the
    # column that says which of the two a model has, and `parent_id` says
    # whether its siblings are scoped by a parent — the same two facts
    # `position_parent_id_for` reads on the controller side.
    def create_resource(resource, model)
      return resource.save unless positioned?(model)

      PositionedResourceOrder.create(resource, sibling_collection(resource, model),
        scope_owner: scope_owner(resource, model),
        parent_id: hierarchical?(model) ? resource.parent_id : nil,
        hierarchical: hierarchical?(model))
    end

    def update_resource(record, attributes)
      return record.update(attributes) unless positioned?(record.class)

      PositionedResourceOrder.update(record, attributes, sibling_collection(record, record.class),
        scope_owner: scope_owner(record, record.class),
        hierarchical: hierarchical?(record.class))
    end

    def delete_resource(record)
      return record.soft_delete unless positioned?(record.class)

      PositionedResourceOrder.destroy(record, sibling_collection(record, record.class),
        scope_owner: scope_owner(record, record.class),
        parent_id: record.respond_to?(:parent_id) ? record.parent_id : nil,
        hierarchical: hierarchical?(record.class))
    end

    # The write's own answer. `PositionedResourceOrder` and `save` both report a
    # refused write by returning false, having left the record's errors on it —
    # the same refusal the live path would have shown the author.
    def write(result)
      result.present?
    end

    def model_for(change)
      RecordTarget.model_for(change.record_type) ||
        raise(ActiveRecord::RecordNotFound, RecordTarget::NOT_FOUND)
    end

    def positioned?(model)
      self.class.ordered?(model)
    end

    def hierarchical?(model)
      self.class.hierarchical?(model)
    end

    # The owner association a model's scope column names, read in the same order
    # `DraftMutation` chose the column to remember and `UniverseScopeResolver`
    # walks to the same answer. A model with none of them is universe-scoped.
    def owner_association(model)
      UniverseScopeResolver::OWNER_ASSOCIATIONS.find do |association|
        model.column_names.include?("#{association}_id")
      end
    end

    def collection_name(model)
      model.model_name.plural
    end

    def scope_owner(record, model)
      association = owner_association(model)
      return @draft.universe unless association

      record.public_send(association)
    end

    def scope_owner_from_payload(model, change)
      association = owner_association(model)
      return universe_scope_owner(model, change) unless association

      id = change.payload["#{association}_id"]
      return if id.blank?

      @draft.universe.public_send(association.to_s.pluralize).find_by(id: id)
    end

    # A universe-scoped record's scope *is* the draft's universe, so the payload's
    # own `universe_id` has nothing to place it in — but it can contradict the
    # draft. A change whose stored scope names another universe is a row this
    # apply cannot vouch for, and writing it into the draft's universe anyway
    # would be silently answering a different question from the one the author
    # asked, so it is reported instead.
    def universe_scope_owner(model, change)
      stored = change.payload["universe_id"]

      return @draft.universe if stored.blank? || stored.to_i == @draft.universe.id

      nil
    end

    # The record's own collection of siblings, which is what the ordering service
    # normalizes. It is the owner's association rather than a table of our own,
    # because the owner is what the controller's `sibling_collection` returns and
    # a list here would be a second thing to keep in step with twenty controllers.
    def sibling_collection(resource, model)
      scope_owner(resource, model).public_send(collection_name(model))
    end
end
