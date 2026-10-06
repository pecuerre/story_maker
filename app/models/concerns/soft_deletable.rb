# Soft delete for content records: a delete marks the record with `deleted_at`
# instead of removing the row, so the data survives and can be restored. The
# default scope hides soft-deleted records from every ordinary query; the
# `with_deleted` and `only_deleted` scopes opt back in.
#
# A model declares which associations cascade with `soft_deletes`:
#
#   class Character < ApplicationRecord
#     include SoftDeletable
#     soft_deletes :relations_as_character1, :relations_as_character2, :ownerships, :scene_characters
#   end
#
# Deleting a parent soft-deletes its whole subtree. Associations that must be
# cleared rather than cascaded (a Section's scenes, an Event's temporal
# references) are handled by overriding `soft_delete_dependencies`.
#
# The column is nullable: `NULL` means the record is live. A partial unique
# index (`WHERE deleted_at IS NULL`) keeps a soft-deleted row from occupying a
# unique key, so re-creating a record with the same slug, membership, or
# presence link stays possible.
module SoftDeletable
  extend ActiveSupport::Concern

  class_methods do
    # Associations whose records are soft-deleted along with this one.
    def soft_deletes(*associations)
      @soft_delete_associations = associations
    end

    def soft_delete_associations
      @soft_delete_associations || []
    end
  end

  included do
    default_scope -> { where(deleted_at: nil) }
    scope :with_deleted, -> { unscope(where: :deleted_at) }
    scope :only_deleted, -> { with_deleted.where.not(deleted_at: nil) }

    # `after_destroy` never fires for a soft delete, because nothing is destroyed: the
    # row is written with a `deleted_at` and the ordinary `after_save` callbacks run
    # instead. A model that repairs something on delete — `OrderedSequence` closing the
    # gap its own deletion left in an ordered collection — therefore needs a callback
    # of its own for these two moments, or it would silently cover only the hard-delete
    # path that the application itself does not use.
    #
    # They run inside the transaction below, immediately after the write that set or
    # cleared `deleted_at`, so a callback that fails rolls the delete back rather than
    # leaving a deleted record beside a sequence it never repaired.
    define_model_callbacks :soft_delete, :restore
  end

  # Mark the record (and its declared dependents) as deleted. The row is kept;
  # the default scope hides it. A soft delete always succeeds: it is a delete,
  # not a validation, so validations are skipped.
  def soft_delete
    self.class.transaction do
      soft_delete_dependencies
      self.class.soft_delete_associations.each do |name|
        public_send(name).find_each(&:soft_delete)
      end
      self.deleted_at = Time.current
      save!(validate: false)
      run_callbacks(:soft_delete)
    end

    self
  end

  # Bring a soft-deleted record back. The default scope hides it again once
  # `deleted_at` is cleared.
  #
  # The `restore` callbacks run inside the same transaction as the write, for the same
  # reason `soft_delete`'s do: a restored record that rejoins an ordered sequence is
  # renumbered there, and a failure has to leave it deleted rather than restored into a
  # sequence that was never repaired.
  def restore
    self.class.transaction do
      self.deleted_at = nil
      save!(validate: false)
      run_callbacks(:restore)
    end

    self
  end

  def deleted?
    deleted_at.present?
  end

  private
    # Hook for models that must clear references instead of cascading. A
    # Section's scenes are ungrouped (their `section_id` is nullified); an
    # Event's temporal references are cleared. Overridden per model.
    def soft_delete_dependencies
    end
end
