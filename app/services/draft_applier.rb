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
# Two answers are derived rather than listed, which is what keeps the applier and
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
# page's list of conflicts cannot disagree. A change that has moved, a change whose
# record is gone, a change the universe cannot place, and a change the live path
# refuses are each reported in the result and none of them is written.
#
# **The reasons are named, and there are five.** `:moved` and `:deleted` are the
# two conflicts; `:missing` is a record that does not resolve at all; `:gone` is a
# delete whose record somebody has already deleted, which is reported as skipped
# rather than claimed as written — nothing was written, and the author's intent
# already holds, so the honest answer is the one the draft's page can print. The
# apply still closes its draft in every one of those cases (below), and the flash
# that follows already says a change could not be applied because the record has
# changed since it was remembered.
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
  # and the other three are `DraftConflictDetector::Report` states.
  SKIP_REASONS = %i[moved deleted missing gone unplaceable refused].freeze

  # What one change's application did: `reason` is nil when the change was
  # written, and otherwise why it was not.
  Outcome = Data.define(:change, :reason) do
    def written?
      reason.nil?
    end
  end

  # The summary an apply returns. `applied` and `skipped` are the two halves the
  # caller needs, and `complete?` is the only question the controller asks.
  Result = Data.define(:applied, :skipped) do
    def applied_count
      applied.size
    end

    def skipped_count
      skipped.size
    end

    def complete?
      skipped.empty?
    end
  end

  def initialize(draft)
    @draft = draft
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
  def apply
    outcomes = []

    ApplicationRecord.transaction do
      @draft.draft_changes.each { |change| outcomes << apply_change(change) }
      @draft.update!(status: "applied")
    end

    Result.new(applied: outcomes.select(&:written?).map(&:change), skipped: outcomes.reject(&:written?))
  end

  private
    def apply_change(change)
      reason =
        case change.action
        when "create" then create(change)
        when "update" then update(change)
        else delete(change)
        end

      Outcome.new(change, reason)
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

    # The detector's answer is the precondition: a change it does not call writable
    # is reported under its own state and nothing is written. `:gone` is the one
    # non-conflict state that reaches here — a delete whose record somebody has
    # already deleted — and it is reported rather than counted as written because
    # this service reports what it wrote.
    def update(change)
      report = @detector.report_for(change)
      return report.state unless report.writable?

      write(update_resource(report.record, change.payload.symbolize_keys)) ? nil : :refused
    end

    def delete(change)
      report = @detector.report_for(change)
      return report.state unless report.writable?

      delete_resource(report.record)

      nil
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
