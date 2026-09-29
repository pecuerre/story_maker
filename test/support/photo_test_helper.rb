require "test_helper"

# The photo fixtures are attached images, not rows the test suite types out, so
# the attachment is built here once: the real `Photo` behaviour is what
# `test/models/photo_test.rb` covers, and every test that needs a record with a
# photo points at one of these.
class ActiveSupport::TestCase
  # A record's photo, once, for the whole suite. `PhotoProcessing` is exercised
  # on the way in, so the stored file is a real 300x300 square.
  def create_photo(universe:, source_file: "test/fixtures/files/photo_one.jpg", name: "Test photo")
    Photo.create!(universe: universe, name: name, source_file: source_file)
  end
end
