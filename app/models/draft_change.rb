# One change remembered inside one draft: create a record, update it, or delete
# it, together with the version it was remembered against.
#
# `record_type` is a polymorphic reference and gets **no** foreign key, because a
# database constraint cannot name a table that varies per row. It is registry
# gated the same way a discussion's is (ADR 0019): the type is matched against
# `Ability::CONTENT_CLASS_NAMES` and only constantized after that match. That is
# what keeps a stored `record_type` from being a loadable-constant injection, and
# what keeps a draft from remembering a change to something that is not universe
# content at all.
#
# `record_id` is nullable for exactly one reason: a `create` remembers a record
# that does not exist yet, and the id is the database's to assign when the change
# is applied. The other two actions remember a record that is already there, so
# `action` decides which of those two shapes is coherent, and the model refuses
# the other. Storing a row that names no record for an update would leave the
# applier nothing to write, and one that names a record for a create would leave
# it deciding which record the payload describes.
#
# `base_version` is the version the record was last seen at, and it is a string
# because it is written into a row and compared days later. Every value stored
# here goes through `VersionStamp.capture`, which normalizes both sides of that
# comparison: a `Time` is never equal to the string it was serialized from, so a
# raw `updated_at` written here would report a conflict on *every* change and
# make the conflict-resolution UI useless rather than merely imperfect.
#
# `payload` holds the remembered attributes. The collaboration plan called this
# column `changes`, and Rails 8.1 refuses that name outright: it is
# `ActiveModel::Dirty`'s, and an attribute that collides raises
# `ActiveRecord::DangerousAttributeError` rather than shadowing it quietly.
# `attributes` is refused the same way, so the payload keeps the name item 24.1
# already uses for opaque stored data in this feature family.
#
# A `delete` carries no payload. It has nothing to remember about the record
# beyond its identity and version, and what the applier does with a payload it
# was handed for one is the applier's decision rather than this model's.
class DraftChange < ApplicationRecord
  ACTIONS = %w[create update delete].freeze

  belongs_to :draft

  # `optional: true` is deliberate, for the reason `Discussion`'s is: Rails' own
  # presence validation on a polymorphic `belongs_to` reads the association,
  # which would `constantize` a stored `record_type` before `RecordTarget` had
  # gated it. The validations below decide whether the reference resolves at all.
  belongs_to :record, polymorphic: true, optional: true

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :record_type, presence: true
  validate :record_type_names_content
  validate :record_id_matches_the_action
  validate :named_record_resolves
  validate :record_belongs_to_drafts_universe
  validate :base_version_matches_the_action

  # The stamp a change about an existing record must remember, and the only
  # supported way to fill the column. Going through `VersionStamp` is the point:
  # the comparison happens between two strings, so a caller that wrote
  # `record.updated_at` here would store a `Time` that can never equal the
  # stamp it is compared against, and every single change would look like a
  # conflict.
  def self.capture_base_version(record)
    VersionStamp.capture(record).to_s
  end

  # The three stored actions, asked about by name. They read as the change's own
  # tense rather than as this model's class, and `creating?` is deliberately not
  # `new_record?`: a remembered create is a *pending* one, and its record does not
  # exist yet.
  def creating?
    action == "create"
  end

  def updating?
    action == "update"
  end

  def deleting?
    action == "delete"
  end

  # A change is append-only once written, and this is what holds that rather than
  # a convention in a comment.
  #
  # What a change says — these attributes, this version — is a statement about one
  # moment. An editable row would let that statement drift away from what was
  # actually observed, and the drift is invisible afterwards: the row still
  # carries a `base_version` captured against the *original* attributes, so a
  # rewritten payload would be applied against a version that described something
  # else. Nothing needs to change a change — every phase that rejects a
  # remembered edit changes the **draft's** status instead, and a draft's row
  # stays editable because that status is exactly what a reviewer moves.
  #
  # An update **raises** rather than being silently ignored, because a caller that
  # believed it had rewritten a remembered change would go on to apply the wrong
  # one. `readonly?` is not the tool: it also refuses `destroy`, which would leave
  # a discarded draft undeletable — the opposite of what the discard workflow
  # needs.
  before_update :refuse_to_be_rewritten

  # The record this change names, or nil when there is none to name.
  #
  # Read through `RecordTarget` rather than through the `record` association, so
  # a soft-deleted record, an unknown id, and an unregistered type are one refusal
  # here — the same one a discussion gets, and the same reason: a remembered
  # change to a record that cannot be found cannot be applied or conflict-checked.
  #
  # It is public because a draft's own page has to name and link the record a
  # change is about, and that page must resolve it the same way the validations
  # below do rather than reaching for the association and getting a different
  # answer: a deleted record would render there and be refused here.
  #
  # The answer is deliberately not remembered. The validations below call it during
  # the save that wrote this change, and a draft's page calls it days later — after
  # the record may have been deleted. A remembered answer would be a record the
  # page links to and a 404 answers.
  def resolved_record
    RecordTarget.find(record_type: record_type, record_id: record_id)
  end

  # The column in `payload` that says which universe, story, or scene a remembered
  # **create** belongs to, or nil when the change carries no payload.
  #
  # `DraftMutation` merged that column in because a payload of submitted values
  # alone cannot say where the record goes, and it named the same way
  # `UniverseScopeResolver` names every model's scope. A draft's page needs the
  # answer too, for the opposite reason: it is the one value in a payload a reader
  # cannot use, so it must be recognised as plumbing rather than printed as a bare
  # id.
  def scope_attribute
    return if payload.blank?

    model = RecordTarget.model_for(record_type)
    association = model && UniverseScopeResolver.owner_association_for(model)

    association ? "#{association}_id" : "universe_id"
  end

  private

    # A `record_type` outside the content registry names a class the application
    # has no rule for, so a draft could remember a change against something that
    # is not a universe record at all. That is a field error the author can
    # answer, not a `NameError` from constantizing an arbitrary stored string.
    def refuse_to_be_rewritten
      raise ActiveRecord::ReadOnlyRecord, "a remembered change is append-only: #{self.class.name} #{id}"
    end

    def record_type_names_content
      return if record_type.blank?
      return if RecordTarget.model_for(record_type).present?

      errors.add(:record_type, I18n.t("drafts.errors.record_type_unknown"))
    end

    def record_id_matches_the_action
      return if action.blank?

      if creating?
        return if record_id.blank?

        errors.add(:record_id, I18n.t("drafts.errors.record_id_for_create"))
      else
        return if record_id.present?

        errors.add(:record_id, I18n.t("drafts.errors.record_id_required"))
      end
    end

    # Read through `RecordTarget` rather than through the `record` association, so
    # a soft-deleted record, an unknown id, and an unregistered type are one
    # refusal here — the same one a discussion gets, and the same reason: a
    # remembered change to a record that cannot be found cannot be applied or
    # conflict-checked.
    def named_record_resolves
      return if action.blank? || creating?
      return if resolved_record.present?

      errors.add(:record, I18n.t("shared.errors.reference.must_exist"))
    end

    # The draft's universe and the change's record are two independent columns,
    # and a foreign key cannot prove they agree. A draft belongs to the universe
    # whose authorization its changes will be applied under, so a change naming
    # a record from somewhere else is refused — the same sentence a discussion
    # gives, because it is the same disagreement.
    def record_belongs_to_drafts_universe
      record = resolved_record
      return if record.nil? || draft.nil? || draft.universe.nil?
      return if RecordTarget.owned_by?(record, draft.universe)

      errors.add(:record, I18n.t("shared.errors.same_scope.universe"))
    end

    # A version is what makes a remembered change safe to apply later: without one
    # there is nothing to compare the record against, and the conservative
    # answer — an unknown base counts as moved — would report a conflict on every
    # change, which is a conflict nobody can learn anything from. A `create` has
    # no record to version yet, so a stamp on one describes nothing.
    def base_version_matches_the_action
      return if action.blank?

      if creating?
        return if base_version.blank?

        errors.add(:base_version, I18n.t("drafts.errors.base_version_for_create"))
      else
        return if base_version.present?

        errors.add(:base_version, I18n.t("drafts.errors.base_version_required"))
      end
    end
end
