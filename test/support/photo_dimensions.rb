# The pixel size of an image the suite has just produced.
#
# Several claims are "the stored file is a 300×300 square", and the only honest
# way to check one is to read the bytes that were actually written. These tests
# used to shell out to ImageMagick's `identify`, which measured the right thing
# only where ImageMagick happened to be installed: CI installs libvips and no
# ImageMagick, so every one of those assertions read an empty string and failed
# on a runner that had processed the photo correctly.
#
# So this asks the same two libraries `PhotoProcessing` chooses between, in the
# same order, and there is no tool for a machine to be missing.
module PhotoDimensions
  # The bytes are not a readable image, or no library on this machine can read
  # them. A caller that is asserting "this file is an image" turns this into its
  # own failure message rather than letting a library error escape.
  class Unreadable < StandardError; end

  module_function

  # `[width, height]` for an image held in memory.
  def of(bytes)
    from_vips(bytes) || from_image_magick(bytes)
  rescue LoadError
    raise Unreadable, "no image library is installed; PhotoProcessing needs libvips or ImageMagick"
  end

  def from_vips(bytes)
    require "vips"
    image = Vips::Image.new_from_buffer(binary(bytes), "")
    [ image.width, image.height ]
  rescue LoadError
    nil
  rescue StandardError => error
    raise Unreadable, "libvips could not read it: #{error.message}"
  end

  def from_image_magick(bytes)
    require "mini_magick"

    # The blob is handed over rather than a path, so MiniMagick writes it to its
    # own tempfile and ImageMagick identifies it from the bytes themselves.
    image = MiniMagick::Image.read(binary(bytes))
    [ image.width, image.height ]
  rescue LoadError
    nil
  rescue StandardError => error
    raise Unreadable, "ImageMagick could not read it: #{error.message}"
  end

  def binary(bytes)
    bytes.to_s.dup.force_encoding(Encoding::BINARY)
  end
end
