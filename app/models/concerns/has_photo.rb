# Gives a record one optional photo.
#
# The photo lives in its own `Photo` row and is referenced by a nullable
# `photo_id`, so a record without one is completely normal: nothing here makes
# a photo required, and every page, list, and form that reads a record must
# already cope with its absence.
#
# The editor never sends an id. It sends the square the author cropped as a data
# URL, and this concern turns that into a new `Photo` inside the record's own
# universe; a "remove" control clears the reference instead. That is what makes
# a cross-universe photo impossible to assign from the interface at all, and
# `photo_belongs_to_the_universe` keeps a direct model write honest — a foreign
# key cannot prove two rows share a universe.
#
# The bytes are turned into a finished square during validation, so an
# unreadable or oversized upload is an ordinary field error and the record is
# never written. The `Photo` row itself is created after the record saves,
# inside the same transaction, because the record's own universe may not have an
# id yet — a Universe is its own photo scope. The photo a record used to have is
# destroyed only after that transaction commits, so a rejected save never takes
# the picture away with it.
module HasPhoto
  extend ActiveSupport::Concern

  included do
    belongs_to :photo, optional: true
    validate :photo_belongs_to_the_universe
    before_validation :prepare_photo_submission
    after_save :store_prepared_photo
    after_commit :destroy_replaced_photo
  end

  # The cropped square submitted by the editor, as a `data:` URL. Assigned by
  # `params.expect` like any other field, and never carried into the database.
  def photo_data=(value)
    @photo_data = value.presence
    @photo_data_submitted = true
  end

  def remove_photo=(value)
    @remove_photo = ActiveModel::Type::Boolean.new.cast(value)
  end

  # The universe a photo for this record must belong to. A Universe is the
  # outermost scope and is its own; every other record reaches its universe
  # through the shared resolver, so content, story-scoped records, and tags are
  # all covered by one rule.
  def photo_scope_universe
    is_a?(Universe) ? self : UniverseScopeResolver.universe_for(self)
  end

  private
    def prepare_photo_submission
      return unless @photo_data_submitted || @remove_photo

      @photo_data_submitted = false
      @prepared_photo = nil
      @replaced_photo = photo

      if @remove_photo
        self.photo = nil
        return
      end

      return if @photo_data.blank?
      if photo_scope_universe.blank?
        errors.add(:photo, "needs a record that belongs to a universe")
        return
      end

      @prepared_photo = PhotoProcessing.from_data_url(@photo_data)
    rescue PhotoProcessing::Invalid => error
      @prepared_photo = nil
      errors.add(:photo, error.message)
    end

    def store_prepared_photo
      prepared = @prepared_photo
      @prepared_photo = nil
      return if prepared.nil?

      stored = Photo.create!(
        universe: photo_scope_universe,
        name: prepared.filename,
        file: { io: prepared.io, filename: prepared.filename, content_type: prepared.content_type }
      )
      # `update_column` rather than `save`: the record is already written, and
      # re-running its validations and callbacks to attach a picture would repeat
      # work the author never asked for.
      self.photo = stored
      update_column(:photo_id, stored.id)
    end

    def photo_belongs_to_the_universe
      return if photo.blank? || photo_scope_universe.blank?
      return if photo.universe_id == photo_scope_universe.id

      errors.add(:photo, "must belong to the same universe")
    end

    def destroy_replaced_photo
      replaced, @replaced_photo = @replaced_photo, nil
      return if replaced.blank?
      return if referenced_elsewhere?(replaced)

      replaced.destroy!
    end

    # A photo belongs to the record it was uploaded for, and an upload always
    # creates a new row, so nothing shares one. Development data and a console
    # can share one deliberately, though, and a row must not be taken away from a
    # record that still points at it.
    def referenced_elsewhere?(candidate)
      Photo::OWNER_CLASS_NAMES.any? do |class_name|
        class_name.constantize.where(photo_id: candidate.id).exists?
      end
    end
end
