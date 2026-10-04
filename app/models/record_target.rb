# Resolves the record a polymorphic reference names, and refuses anything it
# cannot vouch for.
#
# A `record_type`/`record_id` pair arrives from a form, from a URL, or from a
# stored row, and none of those is trustworthy on its own. The type is a string
# that must never be handed to `constantize`, and the id is only meaningful
# inside the universe the request has already authorized. This is the one place
# both halves are checked, so a controller and a model validation cannot end up
# disagreeing about which record a reference means.
#
# The type is matched against `Ability::CONTENT_CLASS_NAMES` — the same registry
# CanCan builds its content rules from — and never against a list of its own, so
# "which classes can a polymorphic reference name" has exactly one answer.
#
# Two consequences of that registry are worth stating, because both are ways a
# generic reference path can leak:
#
# * An unregistered class has no CanCan rule, so `authorize!` refuses it as a
#   forbidden action. An unknown *type* is not a permission decision, though, it
#   is a missing record, so it is refused as not-found. That keeps a stored
#   `record_type` from being usable as an oracle for what exists.
# * A registered class is only ever handed back as an **instance**. The content
#   rules are instance blocks, and CanCan answers a block rule with `true` when
#   it is given the class instead, so a caller that authorized a class rather
#   than a record would be allowed everything it asked about. Returning instances
#   removes the option.
class RecordTarget
  # Every refusal is the same sentence and the same exception, so an unknown type,
  # an unknown id, and a record in another universe are indistinguishable from
  # outside. In the test environment a cross-scope `RecordNotFound` renders as
  # `404`, which is what a reader is meant to see.
  NOT_FOUND = "Record not found"

  class << self
    # The model a type names, or nil when the type is not a registered content
    # class. `record_type` is compared as a string against the registry and only
    # then constantized, so an arbitrary constant in a param or a row can never
    # be loaded.
    def model_for(record_type)
      name = record_type.to_s

      Ability::CONTENT_CLASS_NAMES.include?(name) ? name.constantize : nil
    end

    # The record a reference names, or nil when the type, the id, or the row does
    # not hold up. A soft-deleted record does not resolve: the default scope hides
    # it from here exactly as it hides it from every other ordinary query.
    def find(record_type:, record_id:)
      model_for(record_type)&.find_by(id: record_id)
    end

    # `find`, with the universe check folded in, and a refusal raised rather than
    # returned. `within` is the universe the request has already authorized; a
    # record that resolves to no universe at all fails the same check, because a
    # reference that cannot place its record is not a reference this application
    # can honour.
    def find!(record_type:, record_id:, within: nil)
      record = find(record_type:, record_id:)
      raise ActiveRecord::RecordNotFound, NOT_FOUND if record.nil?
      raise ActiveRecord::RecordNotFound, NOT_FOUND if within.present? && !owned_by?(record, within)

      record
    end

    # `find`, for the one caller whose question is whether the row is *still
    # there* rather than whether it is visible: `DraftConflictDetector`, which has
    # to tell a record somebody has since deleted from a record that was never
    # there, because those two are different answers to "has this change moved?"
    # and `find` collapses them.
    #
    # It stays here rather than in the detector so that there is still one place a
    # stored `record_type`/`record_id` pair is turned into a record. The registry
    # gate and the universe check are not repeated by the caller that wants a
    # deleted row; a detector with its own query would be a second reader of the
    # same stored reference, which is the drift this class exists to prevent.
    #
    # Soft-deletability is asked of the model as a capability rather than kept in a
    # list of our own: a model that includes `SoftDeletable` answers `with_deleted`
    # and one that does not — a `Photo`, which is destroyed rather than marked —
    # answers `find_by` exactly as `find` does. `test/models/record_target_test.rb`
    # holds the two against each other, so a model that grows a `deleted_at` column
    # without the concern fails the suite rather than silently answering as though
    # nothing could be deleted.
    def find_including_deleted(record_type:, record_id:)
      model = model_for(record_type)
      return if model.nil?

      (model.respond_to?(:with_deleted) ? model.with_deleted : model).find_by(id: record_id)
    end

    # Whether a record a reference resolved to has been soft-deleted. A model that
    # cannot be soft-deleted is not deleted, which is why this is a capability
    # question and not a column read: `Photo` rows are destroyed, so there is no
    # `deleted_at` to be blank.
    def soft_deleted?(record)
      record.respond_to?(:deleted?) && record.deleted?
    end

    # Whether a reference resolves to a record inside `within`. This is the shape
    # a model validation wants; `find!` is the shape a controller wants; both ask
    # the same question so they cannot answer it differently.
    def resolvable?(record_type:, record_id:, within: nil)
      record = find(record_type:, record_id:)

      record.present? && (within.nil? || owned_by?(record, within))
    end

    # Whether a record belongs to a universe, resolved through the one shared walk
    # that `Ability` and the view helpers already use. Comparing the resolved
    # universe rather than a foreign key is deliberate: it is the only way that
    # agrees with what the authorization check is about to decide.
    def owned_by?(record, universe)
      UniverseScopeResolver.universe_for(record) == universe
    end
  end
end
