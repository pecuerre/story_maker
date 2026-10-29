require "rubygems/package"
require "stringio"
require "yaml"
require "zlib"

# Builds one downloadable `.tar.gz` backup of a universe.
#
# The archive has three parts, and only the first is authoritative:
#
# - `data/` — a lossless table dump from `UniverseBackup::DataDump`, including
#   soft-deleted core rows and every HABTM join;
# - `photos/` — the stored 300x300 files named by `data/photos.yml`;
# - `content/` — a human-readable projection in the story-interchange shape from
#   `UniverseBackup::ContentProjection`.
#
# The README inside the archive says which part is which and what is deliberately
# absent. Restore is a separate, destructive command and is not implemented here.
module UniverseBackup
  class Archive
    FORMAT_VERSION = 1

    attr_reader :universe, :generated_at

    def initialize(universe, generated_at: Time.current)
      @universe = universe
      @generated_at = generated_at
    end

    def to_s
      io = StringIO.new
      gzip = Zlib::GzipWriter.new(io)
      tar = Gem::Package::TarWriter.new(gzip)

      files.each { |path, content| add_file(tar, path, content) }
      dump.photo_files.each { |photo| add_file(tar, photo.path, photo.bytes) if photo.path }

      tar.close
      gzip.close unless gzip.closed?
      io.string
    end

    def filename
      "#{universe.slug}-backup-#{generated_at.utc.strftime("%Y%m%d-%H%M%S")}.tar.gz"
    end

    private
      def files
        @files ||= {
          "backup.yml" => manifest,
          "README.md" => readme
        }.merge(dump.files).merge(ContentProjection.new(universe).files)
      end

      def dump
        @dump ||= DataDump.new(universe)
      end

      def manifest
        YAML.dump(
          "format" => "universe-backup",
          "format_version" => FORMAT_VERSION,
          "generated_at" => generated_at.utc.iso8601,
          "universe" => {
            "id" => universe.id,
            "name" => universe.name,
            "slug" => universe.slug
          },
          "counts" => dump.counts,
          "photos" => {
            "count" => dump.photo_files.count { |photo| photo.path },
            "missing" => dump.missing_photo_files
          },
          "deferred_tables" => dump.deferred_tables,
          "notes" => [
            "data/ is the lossless copy; content/ is a human-readable projection.",
            "Soft-deleted core records are included; soft-deleted users, memberships, and history are not in this slice.",
            "Restore is not implemented; it will be a separate, destructive, confirmation-gated command."
          ]
        )
      end

      def readme
        <<~MARKDOWN
          # Universe backup: #{universe.name}

          Generated #{generated_at.utc.iso8601} for `#{universe.slug}`.

          ## What is here

          | Path | Contents |
          |---|---|
          | `backup.yml` | format version, counts, and the list of deferred tables |
          | `data/` | the lossless table dump — the authoritative backup |
          | `photos/` | the stored 300×300 files named by `data/photos.yml` |
          | `content/` | a human-readable projection in the story-interchange shape |

          `data/` keeps the application's own columns, including foreign-key ids
          and soft-deleted core rows, so a restore can rebuild the universe
          exactly. `content/` is a convenience view for a reader, not the copy a
          restore reads. The application does not store every field the
          interchange layout asks for, so the projection writes `— TBD` for
          those fields and omits records the layout has no place for.

          ## What is deliberately absent

          This is the core-data slice. Users, Universe memberships, drafts and
          their change history, review requests, notifications, and API tokens
          are not in the archive; they carry identity, access, or somebody else's
          unfinished work, and a later slice owns them. See `backup.yml`'s
          `deferred_tables`.

          ## Restore

          Restore is not implemented. When it arrives it will be a separate,
          destructive command that asks for explicit confirmation and never reuses
          the development-data reset path.
        MARKDOWN
      end

      def add_file(tar, path, content)
        bytes = content.to_s
        tar.add_file_simple(path, 0o644, bytes.bytesize) do |io|
          io.write(bytes)
        end
      end
  end
end
