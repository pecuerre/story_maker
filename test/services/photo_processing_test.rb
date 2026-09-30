require "test_helper"

# The rules that keep an upload from becoming something the application would
# not want to store. The crop happens in the editor, so none of this is visible
# in the interface; it is the boundary the editor is trusted not to cross.
class PhotoProcessingTest < ActiveSupport::TestCase
  setup do
    @landscape = Rails.root.join("db/photos/dark/landscape.jpg").binread
    @portrait = Rails.root.join("db/photos/dark/portrait.jpg").binread
  end

  test "produces a 300x300 square from a non-square source" do
    [ @landscape, @portrait ].each do |bytes|
      result = PhotoProcessing.from_data_url(data_url(bytes))

      assert_equal [ 300, 300 ], dimensions_of(result.io)
      assert_equal "image/jpeg", result.content_type
    end
  end

  test "the result is named after the source" do
    result = PhotoProcessing.from_data_url(data_url(@landscape))

    assert_equal "photo.jpg", result.filename
  end

  test "reads a file from the repository" do
    result = PhotoProcessing.from_path("db/photos/dark/portrait.jpg")

    assert_equal "portrait.jpg", result.filename
    assert_equal "image/jpeg", result.content_type
  end

  test "refuses bytes that are not a supported image" do
    [
      "not an image at all",
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"10\"></svg>",
      "<html><body>x</body></html>",
      "%PDF-1.4\n%test",
      ""
    ].each do |body|
      assert_raises(PhotoProcessing::Invalid) do
        PhotoProcessing.from_data_url(data_url(body))
      end
    end
  end

  test "refuses a payload that is only a data URL in appearance" do
    assert_raises(PhotoProcessing::Invalid) { PhotoProcessing.from_data_url("https://example.com/x.jpg") }
    assert_raises(PhotoProcessing::Invalid) { PhotoProcessing.from_data_url("") }
  end

  test "refuses a payload above the size limit" do
    oversized = "x" * (PhotoProcessing::MAX_SOURCE_BYTES + 1)

    error = assert_raises(PhotoProcessing::Invalid) { PhotoProcessing.from_data_url(data_url(oversized)) }
    assert_includes error.message, "larger than"
  end

  test "refuses a repository path that does not exist" do
    assert_raises(PhotoProcessing::Invalid) { PhotoProcessing.from_path("db/photos/dark/missing.jpg") }
  end

  test "the stored square carries none of the source metadata" do
    # A real photo routinely carries GPS coordinates and a camera serial. The
    # stored file is re-encoded, so none of that survives.
    result = PhotoProcessing.from_data_url(data_url(@landscape))

    refute_match(/Exif/, result.io.read)
  end

  private
    def data_url(bytes, type: "image/jpeg")
      "data:#{type};base64,#{Base64.strict_encode64(bytes)}"
    end

    def dimensions_of(io)
      io.rewind
      PhotoDimensions.of(io.read)
    end
end
