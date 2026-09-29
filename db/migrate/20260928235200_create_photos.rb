# A Photo is the single, always-square image a record can carry.
#
# It is a model of its own rather than a `photo`/`photo_path` column on each
# record, so the bytes, the 300x300 normalisation, and the optional foreign key
# live in one place. Every reference to it is optional: a record with no photo
# is valid everywhere, which is why the column added by
# `AddPhotoToRecords` is nullable on every table.
#
# `universe_id` is the scope. A foreign key cannot prove that a photo and the
# record pointing at it belong to the same universe, so `HasPhoto` checks that
# in the model — the same application-level rule the tag and event references
# use.
class CreatePhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :photos do |t|
      t.references :universe, null: false, foreign_key: true
      # The original file name, kept as a human label and as the stable
      # identifier the development data references a photo by.
      t.string :name
      t.string :slug, null: false

      t.timestamps
    end
  end
end
