# Keeps a `position` sequence contiguous when a record leaves or rejoins it **without**
# going through `PositionedResourceOrder`.
#
# The service is the application path: a controller mutation, or a `DraftApplier` run,
# renumbers a whole sibling group inside one transaction that holds the scope owner's
# lock. This concern is the safety net for the paths that reach a positioned model
# directly — `scene.destroy!`, `record.soft_delete`, `record.restore`, a console command,
# an import — so a mistake made outside the service closes its own gap instead of leaving
# `[0, 1, 3]` behind for the next reader to puzzle over.
#
# **Three moments, and why those three.** A record leaves a live sequence by being hard
# destroyed (`after_destroy`) or soft deleted (`after_soft_delete`), and rejoins one by
# being restored (`after_restore`). `SoftDeletable` defines the latter two callbacks
# around the `save!` that writes `deleted_at`, inside the transaction that wrote it, so a
# normalization failure rolls the delete back rather than leaving a hole next to it.
#
# **Restore is included, and it is the reason the scope includes the record itself.** The
# survivors were renumbered when the record left, so its own `position` is a stale slot
# that may now be occupied by a record created while it was away. Renumbering the group
# in `(position, id)` order puts the returning record back in that slot — its older id
# wins the tie — rather than always appending it to the end, which would silently
# reorder a story every time a draft was undone.
#
# **A hard destroy and a soft delete need no exclusion of the record.** Its row is gone,
# or its `deleted_at` is set, so the model's default scope keeps it out of the very query
# that renumbers the rest. Excluding it by id would have been redundant on those two
# paths and wrong on restore.
#
# **This is repair, not concurrency control.** It runs in whatever transaction the
# caller's write runs in — often none, when a console calls `destroy!` directly — and
# SQLite has no portable row lock. The service remains the authority for an application
# mutation; this only makes an out-of-band write self-consistent afterwards. Raw SQL and
# `update_column` still bypass it entirely, because no callback fires for a statement
# that skips the model. See ADR 0009 and `docs/known_quirks.md`.
module OrderedSequence
  extend ActiveSupport::Concern

  # `SoftDeletable` owns the two non-destroy callbacks this concern listens to, so it is
  # a declared dependency rather than an assumption about include order: a model may
  # write `include Hierarchical` (which includes this) above `include SoftDeletable`, and
  # `after_soft_delete` would otherwise be an undefined method at class-definition time.
  # Every positioned model soft-deletes, so the dependency grants nothing it did not have.
  include SoftDeletable

  included do
    after_destroy :normalize_ordered_sequence
    after_soft_delete :normalize_ordered_sequence
    after_restore :normalize_ordered_sequence
  end

  class_methods do
    # Declares the owner association a **flat** sequence lives inside: `position` orders
    # a Story's Scenes and a Scene's Elements, and the owner holds every member of the
    # group. A hierarchical model declares nothing here — it already has a `parent_id`
    # and overrides `ordered_sequence_scope` with that narrower group.
    def ordered_sequence_within(owner_association)
      @ordered_sequence_owner = owner_association.to_sym
    end

    # The declared flat owner, or nil for a hierarchical model. Read by
    # `ordered_sequence_scope` and by the test that holds this declaration against the
    # owner's own associations.
    def ordered_sequence_owner
      @ordered_sequence_owner
    end

    # **The columns whose values decide which sequence a record is in.** Two records
    # with the same values for all of them are ordered against each other; two records
    # that differ on any of them are in different sequences and never move together.
    #
    # This is the group definition `ordered_sequence_scope` reads on an instance, stated
    # as data so a caller that holds no record — `SequenceNormalizer`, walking whole
    # tables — answers the same question the instance does. `Hierarchical` overrides it,
    # because its group is narrower: a `parent_id` as well as the owning scope.
    def ordered_sequence_group_columns
      [ :"#{ordered_sequence_owner}_id" ]
    end
  end

  private

    # Every live record in this record's own sequence, **including** this one while it is
    # live, ordered the way the sequence is read. Hierarchical models override this with
    # the group their `parent_id` names; the default is the flat case, whose group is
    # everything the declared owner holds.
    #
    # An absent or unsaved owner yields nil rather than a query: a record whose scope is
    # gone has no sequence left to repair, and `owner.public_send(...)` on nil would turn
    # a cleanup path into a `NoMethodError`.
    def ordered_sequence_scope
      owner_name = self.class.ordered_sequence_owner
      return if owner_name.nil?

      owner = public_send(owner_name)
      return if owner.nil? || !owner.persisted?

      owner.public_send(self.class.model_name.collection)
    end

    def normalize_ordered_sequence
      scope = ordered_sequence_scope
      return if scope.nil?

      scope.reorder(:position, :id).lock.each_with_index do |sibling, index|
        sibling.update_columns(position: index) unless sibling.position == index
      end
    end
end
