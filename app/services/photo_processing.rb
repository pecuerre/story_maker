# Turns whatever was submitted into the one image a Photo stores: a 300x300
# square, re-encoded, with the source metadata dropped.
#
# The editor already crops to a square in the browser, and this service is the
# authority anyway. A client is not trusted with the stored size: a request can
# skip the cropper entirely and the file is still cropped and resized here.
# Re-encoding is also what makes the stored bytes safe to serve — the stored
# file is an image this application produced, never the submitted bytes, so
# metadata, an unexpected format, and anything hidden inside the upload have
# nowhere to survive.
#
# libvips is the processor in the Docker image and in CI; ImageMagick is used
# when libvips is not installed, so a workstation that has only that still works.
class PhotoProcessing
  SIZE = 300
  FORMAT = :jpg
  CONTENT_TYPE = "image/jpeg"

  # A submitted crop is a base64 data URL because every editor in this
  # application — the JSON modals, the taxonomy editor's modal, and the plain
  # full-page forms — posts one ordinary form field rather than a multipart
  # body. Keeping the transport identical everywhere is what lets one control
  # serve all three page patterns.
  DATA_URL = %r{\Adata:image/[A-Za-z0-9.+\-]+;base64,(.+)\z}m

  # The submitted bytes are checked against these signatures before any image
  # library sees them. The point is not to be strict about encoding, it is to
  # keep formats that can carry code or that a renderer would interpret — SVG
  # above all — away from the pipeline. A client labels its own data URL, so
  # the header is never what this is based on.
  SIGNATURES = {
    "image/jpeg" => [ "\xFF\xD8\xFF".b ],
    "image/png" => [ "\x89PNG\r\n\x1A\n".b ],
    "image/gif" => [ "GIF87a".b, "GIF89a".b ],
    "image/webp" => [ "RIFF".b ]
  }.freeze

  # Bounds the work one request can ask for. A 300x300 JPEG is a few tens of
  # kilobytes, so this is generous for a crop while still refusing a payload
  # that would otherwise be held in memory and decoded.
  MAX_SOURCE_BYTES = 8.megabytes

  class Invalid < StandardError; end

  Result = Struct.new(:io, :filename, :content_type, keyword_init: true)

  class << self
    def from_data_url(data_url)
      match = DATA_URL.match(data_url.to_s)
      raise Invalid, "could not be read as an image" if match.nil?

      build(decode_base64(match[1]), filename: "photo")
    end

    # Development data names a file in the repository rather than carrying
    # bytes, so a sample universe can show a real photo.
    def from_path(path)
      full_path = Rails.root.join(path)
      raise Invalid, "could not be read as an image" unless full_path.file?

      build(full_path.binread, filename: full_path.basename(".*").to_s)
    end

    # Every path ends here: the submitted bytes go in, the finished square
    # comes out.
    def build(bytes, filename: "photo")
      raise Invalid, "could not be read as an image" if bytes.blank?
      if bytes.bytesize > MAX_SOURCE_BYTES
        raise Invalid, "is larger than #{MAX_SOURCE_BYTES / 1.megabyte} MB"
      end

      raise Invalid, "could not be read as an image" unless supported_image?(bytes)

      stored = Tempfile.new([ "photo", ".jpg" ], binmode: true)
      stored.binmode

      Tempfile.create([ "photo-upload", ".image" ], binmode: true) do |source|
        source.binmode
        source.write(bytes)
        source.flush

        stored.write(square(source.path).binmode.read)
        stored.flush
        # The caller reads the finished file from the beginning, so the write
        # position must not be left at the end of it.
        stored.rewind
      end

      Result.new(
        io: stored,
        filename: "#{File.basename(filename, '.*').presence || 'photo'}.jpg",
        content_type: CONTENT_TYPE
      )
    rescue Invalid
      raise
    rescue *processing_errors => error
      raise Invalid, "could not be read as an image (#{error.class.name.demodulize})"
    end

    # Which image library is available. libvips ships in the Docker image and is
    # installed in CI; ImageMagick is the fallback so the application still runs
    # on a workstation that has only that.
    def processor
      return @processor if defined?(@processor)

      @processor = begin
        ImageProcessing::Vips
        ImageProcessing::Vips
      rescue LoadError
        ImageProcessing::MiniMagick
      end
    end

    private
      def square(path)
        pipeline = processor.source(path).resize_to_fill(SIZE, SIZE)
        pipeline = drop_metadata(pipeline)
        pipeline.convert(FORMAT).call
      end

      # A photo routinely carries GPS coordinates, a camera serial, and a
      # timestamp in its metadata, and none of that belongs in a story bible.
      # ImageMagick keeps everything unless told otherwise; libvips' JPEG and
      # PNG savers already drop it unless asked to keep it.
      def drop_metadata(pipeline)
        processor == ImageProcessing::MiniMagick ? pipeline.strip : pipeline
      end

      def supported_image?(bytes)
        SIGNATURES.any? do |_, signatures|
          signatures.any? do |signature|
            if signature == "RIFF".b
              bytes.byteslice(0, 4) == signature && bytes.byteslice(8, 4) == "WEBP".b
            else
              bytes.byteslice(0, signature.bytesize) == signature
            end
          end
        end
      end

      def decode_base64(payload)
        Base64.strict_decode64(payload.gsub(/\s+/, ""))
      rescue ArgumentError
        raise Invalid, "could not be read as an image"
      end

      # Each backend reports a failure its own way, and a library that is not
      # installed cannot even be named.
      def processing_errors
        @processing_errors ||= if processor == ImageProcessing::MiniMagick
          [ ImageProcessing::Error, MiniMagick::Error ]
        else
          [ ImageProcessing::Error, (::Vips::Error if defined?(::Vips)) ].compact
        end
      end
  end
end
