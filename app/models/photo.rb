# A Photo is the one image a record may carry.
#
# It exists as its own model rather than as a `photo`/`photo_path` column on
# every record, so the bytes, the always-square 300x300 normalisation, and the
# optional foreign key are defined once. Every record that includes `HasPhoto`
# references it optionally; a record without a photo is completely normal.
#
# The stored file is only ever the finished 300x300 crop: the editor sends the
# square the author cropped, and `PhotoProcessing` resizes and re-encodes it
# before it is attached, so neither the original upload nor its metadata is
# written. Re-encoding is also what makes the attachment safe to serve — the
# stored bytes are an image this application produced, whatever was submitted.
class Photo < ApplicationRecord
  include HasSlug

  # One square size, used for the stored file and by the editor's crop stage, so
  # the two can never disagree about what a photo looks like.
  SIZE = 300

  # Every model that can point at a Photo. Replacing a photo destroys the row it
  # superseded, and this is what makes that safe: a row is only removed once no
  # record still refers to it. It is one explicit list, like `Ability`'s content
  # registry, and a model test keeps it equal to the models that include
  # `HasPhoto` — the failure of a missing entry is a photo that is destroyed
  # while another record still shows it.
  OWNER_CLASS_NAMES = %w[
    Universe
    Story
    Section
    Scene
    Character
    Location
    Item
    Event
    Relation
    Ownership
    CharacterTag
    LocationTag
    ItemTag
    EventTag
    RelationTag
    OwnershipTag
    SectionTag
    SceneTag
  ].freeze

  belongs_to :universe
  has_one_attached :file

  validate :file_is_attached

  # A Photo has no URL of its own: an Active Storage attachment's URL is built by
  # the request that serves it, so a view asks the router through
  # `ApplicationHelper#record_photo_url`. A model method could only return `nil`.

  # Attach a file from the repository rather than from a request, which is how
  # the development data manifests and the test fixtures supply one. The bytes go
  # through exactly the same processing an upload does, so a sample photo is
  # cropped and resized on the way in like any other and the stored file is
  # never the source asset.
  def source_file=(path)
    processed = PhotoProcessing.from_path(path)
    file.attach(io: processed.io, filename: processed.filename, content_type: processed.content_type)
    # The manifest names the photo; the file name is only a fallback for a photo
    # created without one. Overwriting it would leave the manifest's reference
    # and the record's own slug disagreeing.
    self.name = processed.filename if name.blank?
  end

  private
    # A Photo row exists to name an image, so a row without one is never a
    # useful record. Written out rather than using Active Storage's `attached:`
    # validator, which this Rails version does not ship.
    def file_is_attached
      errors.add(:file, "must be attached") unless file.attached?
    end
end
