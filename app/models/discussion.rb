# A conversation attached to exactly one record.
#
# The thread is addressed through the record it belongs to, which is why there is
# one per record rather than a collection: a reader opens a Character and asks
# what was said about *that* Character, and the answer is a single thread.
#
# Two scopes are stored and both are checked. `record_type`/`record_id` is a
# polymorphic reference, so nothing about it can be trusted: it is resolved only
# through `RecordTarget`, which matches the type against the content registry
# before constantizing it. `universe_id` is a real foreign key, but a foreign key
# cannot prove that the universe and the record agree — they are independent
# columns — so the model validates the resolved record against the stored
# universe. Neither half is believed on its own.
class Discussion < ApplicationRecord
  # `optional: true` is deliberate even though a thread always has a record. The
  # polymorphic reader constantizes whatever `record_type` says, so Rails' own
  # presence validation would resolve a stored type *before* anything had checked
  # that it names a registered content class — reopening the loadable-constant
  # hole `RecordTarget` exists to close. The validations below are what decide
  # whether the reference resolves at all, and they go through `RecordTarget`.
  belongs_to :record, polymorphic: true, optional: true

  belongs_to :universe

  # A thread reads as a conversation, so its order is defined here rather than at
  # each call site. Two messages written inside one clock tick still have an order.
  has_many :messages, -> { order(:created_at, :id) },
           class_name: "DiscussionMessage", dependent: :destroy

  validate :record_reference_exists
  validate :record_belongs_to_universe

  # A thread has no slug of its own: what identifies it is the record pair the
  # unique index already holds, and one thread per record means there is never a
  # second name to collide with. The development-data loader still needs a stable
  # identifier to reference a thread from a manifest, and a thread's title is what
  # identifies it there — so this is `slugify` alone, without `HasSlug`, whose slug
  # column and name callback a thread has no use for.
  def self.slugify(value)
    value.to_s.parameterize.presence
  end

  private

    def record_reference_exists
      return if resolved_record.present?

      errors.add(:record, I18n.t("shared.errors.reference.must_exist"))
    end

    def record_belongs_to_universe
      record = resolved_record
      return if record.nil? || universe.nil?
      return if RecordTarget.owned_by?(record, universe)

      errors.add(:record, I18n.t("shared.errors.same_scope.universe"))
    end

    # Read through `RecordTarget` rather than through the `record` association on
    # purpose: this is the one reader that has to be safe for a `record_type` no
    # registry entry matches.
    def resolved_record
      @resolved_record ||= RecordTarget.find(record_type: record_type, record_id: record_id)
    end
end
