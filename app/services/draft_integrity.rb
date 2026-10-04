# Says, before a run starts, whether a draft holds a change the applier cannot
# interpret at all.
#
# **This is a different question from the conflict detector's.** `DraftConflictDetector`
# asks whether a remembered change can still be *written* — the record has moved, somebody
# has deleted it, it is not there at all. Every one of those is an answer the author (or a
# reviewer) can be shown and choose about. This class asks the prior question: can the
# applier read the row well enough to get that far? A `record_type` outside the content
# registry, or a payload naming a value no field on that model has, is not a conflict
# because there is nothing to choose between — the row could only have been written by
# something that is not this application (a hand-edited `draft_changes` row, a model that
# has since been renamed, development data written by an older loader).
#
# **The applier still raises on these; that decision is ADR 0021's and it is unchanged.**
# What this class exists for is the *shape of the answer*: a raise escaping a controller
# through `rescue_from ActiveRecord::RecordNotFound` reads as "this draft does not exist",
# which is a statement about the wrong thing entirely — and a reviewer reading it would
# think a submission had vanished rather than that one remembered change is damaged. So
# the controller asks this question first and answers in its own words, naming the change
# it cannot read, and writes nothing at all: the run rolls back today, so the draft stays
# open and the author's own way out (**Discard**) is untouched.
#
# **An answer per change, in the order the changes were remembered.** One damaged change
# in nineteen is still a run that cannot happen, and a summary that said "19 of 20" would
# be a second accounting of the same draft.
class DraftIntegrity
  # The two ways a stored change cannot be read, named once so that the sentence on a
  # page, a test, and the reader are one vocabulary rather than a list spelled out at the
  # call site. `:unknown_record_type` is the registry gate refusing a class;
  # `:unknown_attribute` is a payload key the model cannot be handed.
  REASONS = %i[unknown_record_type unknown_attribute].freeze

  # One unreadable change, and why. `attribute` is the offending payload key for
  # `:unknown_attribute` and nil otherwise, because "a value this record has no field
  # for" is not something an author can act on without being told *which* one.
  Offender = Data.define(:change, :reason, :attribute) do
    def unknown_record_type?
      reason == :unknown_record_type
    end

    def unknown_attribute?
      reason == :unknown_attribute
    end
  end

  def initialize(draft)
    @draft = draft
  end

  # Every change in the draft the applier could not interpret, in the order they were
  # remembered. Memoized for one request, the same lifetime `DraftApplier`'s own detector
  # has: this is asked by the page that renders and by the apply that refuses, and the two
  # have to be reading the same rows.
  def offenders
    @offenders ||= @draft.draft_changes.filter_map { |change| offender_for(change) }
  end

  # Whether anything in this draft is unreadable. This is the question a controller asks
  # before running the applier, and the question the page behind that refusal asks when it
  # renders — one predicate, so a page cannot say a draft is damaged while an apply
  # cheerfully attempted it.
  def damaged?
    offenders.any?
  end

  private
    # One change, or nothing. **The question is what the applier would raise on, which
    # is why the action is read first.**
    #
    #   * A **create** needs a class before anything else — the applier's `model_for`
    #     raises for a type outside the registry — and then needs every payload key to
    #     have a writer, because it hands the whole payload to `new`.
    #   * An **update** names a record the detector has already resolved, so a type
    #     outside the registry is `:missing` there rather than a raise: refusing the
    #     whole run over a change the applier would have skipped is a new refusal, not
    #     a clearer answer. The payload is still checked, because `update` hands it to
    #     `record.update`.
    #   * A **delete** carries no payload and needs no class, so nothing about it can
    #     be unreadable.
    #
    # Reading the action is also what keeps this class from becoming a second registry
    # gate: `DraftConflictDetector` owns "can this change still be written", and a row
    # it already reports gets no second opinion from here.
    def offender_for(change)
      model = RecordTarget.model_for(change.record_type)

      if change.creating?
        return Offender.new(change, :unknown_record_type, nil) if model.nil?
      elsif model.nil?
        return
      end

      attribute = unwritable_attribute(model, change)
      attribute ? Offender.new(change, :unknown_attribute, attribute) : nil
    end

    # The first payload key the model could not be handed, or nil when every one of them
    # is writable.
    #
    # **An unsaved instance is what answers, rather than the class or its columns.** The
    # applier does `owner.public_send(collection).new(change.payload.symbolize_keys)` and
    # `record.update(attributes)`, so what a payload may name is "something with a writer",
    # which is a superset of the columns: `character_tag_ids` (a collection writer) and the
    # two virtual photo fields `HasPhoto` keeps in instance variables are both remembered
    # values the applier has to hand over, and neither is a column. A check against
    # `column_names` would therefore call a perfectly appliable photo change damaged —
    # the same kind of false alarm as a row the detector calls a conflict nobody can
    # answer (ADR 0021).
    #
    # The instance rather than the class because attribute writers are *generated lazily*:
    # `Scene.method_defined?(:name=)` is false until something has defined the attribute
    # methods, which would report every remembered create as damaged. Building one
    # instance per class does that once, and it is the same object the applier would hand
    # the payload to.
    #
    # A remembered delete carries no payload, and a create's scope column is a column like
    # any other, so neither needs a case of its own here.
    def unwritable_attribute(model, change)
      return if change.payload.blank?

      probe = probe_for(model)

      change.payload.keys.find { |name| !probe.respond_to?(:"#{name}=") }
    end

    def probe_for(model)
      @probes ||= {}

      @probes[model.name] ||= model.new
    end
end
