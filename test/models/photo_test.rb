require "test_helper"

# A Photo is the one image a record may carry. What matters here is that the
# stored file is always the finished 300x300 square and never the upload: the
# crop happens in the editor, but a client is not trusted with the stored size,
# and the stored bytes are always an image this application produced.
class PhotoTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
  end

  test "stores a 300x300 square even when the source is not square" do
    portrait = create_photo(universe: @universe, source_file: "db/photos/dark/portrait.jpg")
    landscape = create_photo(universe: @universe, source_file: "db/photos/dark/landscape.jpg")

    [ portrait, landscape ].each do |photo|
      assert_equal [ 300, 300 ], dimensions(photo), "a stored photo is a 300x300 square"
    end
  end

  test "stores a JPEG whatever the source format was" do
    photo = create_photo(universe: @universe, source_file: "db/photos/dark/landscape.jpg")

    assert_equal "image/jpeg", photo.file.content_type
  end

  test "keeps the manifest name rather than the file name" do
    photo = create_photo(universe: @universe, name: "Winden")

    assert_equal "Winden", photo.name
    assert_equal "winden", photo.slug
  end

  test "falls back to the file name when nothing names the photo" do
    photo = Photo.create!(universe: @universe, source_file: "db/photos/dark/portrait.jpg")

    assert_equal "portrait.jpg", photo.name
  end

  test "requires a universe" do
    photo = Photo.new(name: "Orphan", source_file: "db/photos/dark/portrait.jpg")

    assert_not photo.valid?
    assert_includes photo.errors.full_messages, "Universe must exist"
  end

  test "requires a file" do
    photo = Photo.new(universe: @universe, name: "Empty")

    assert_not photo.valid?
    assert_includes photo.errors.full_messages, "File must be attached"
  end

  test "drops the metadata an uploaded photo carries" do
    # A real photo routinely carries GPS coordinates and a camera serial in its
    # EXIF data. None of that belongs in a story bible, so the stored file is
    # re-encoded rather than kept.
    photo = create_photo(universe: @universe, source_file: "test/fixtures/files/photo_one.jpg")

    refute_match(/Exif/, photo.file.download, "the stored file should carry no EXIF block")
  end

  test "the owner list is exactly the models that can carry a photo" do
    Photo::OWNER_CLASS_NAMES.each do |name|
      assert name.constantize.include?(HasPhoto), "#{name} is listed as a photo owner but cannot carry one"
    end

    with_photo = ApplicationRecord.descendants.select { |model| model.include?(HasPhoto) }.map(&:name).sort
    assert_equal Photo::OWNER_CLASS_NAMES.sort, with_photo
  end

  private
    # Read from the stored bytes rather than from a recorded value: the claim
    # under test is what was actually written, and the analyzer is whichever
    # image library the machine has.
    def dimensions(photo)
      PhotoDimensions.of(photo.file.download)
    rescue PhotoDimensions::Unreadable
      flunk "the stored file must be a readable image"
    end
end
