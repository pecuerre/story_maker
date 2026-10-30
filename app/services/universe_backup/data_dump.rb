require "yaml"

# A lossless, table-shaped dump of one universe's core records.
#
# The dump is the authoritative half of a backup. It keeps one YAML file per
# table, with the row's own columns (including soft-deleted rows), and one file
# per HABTM join table. It does not resolve foreign keys into slugs: the ids are
# what a restore will need to remap, and inventing a second reference language
# here would make the backup disagree with the database it copies.
#
# **Deferred on purpose.** Users, memberships, drafts and their change history,
# review requests, notifications, and API tokens are not here. They carry
# identity, access, or somebody else's unfinished work, and the backup's
# sensitive-data slice owns them. The archive manifest names them so a reader
# cannot mistake this for a complete backup of those tables.
module UniverseBackup
  class DataDump
    CORE_MODELS = %w[
      Universe
      Story
      CanonRule
      SectionTag
      SceneTag
      Section
      LocationTag
      Location
      Route
      CharacterTag
      FactionTag
      Faction
      Character
      FactionRelationship
      RelationTag
      Relation
      ItemTag
      Item
      OwnershipTag
      Ownership
      EventTag
      Event
      Plot
      StoryTrope
      Scene
      SceneTrope
      SceneElement
      SceneDialogueTurn
      SceneEvent
      SceneCharacter
      SceneItem
      SceneLocation
      Discussion
      DiscussionMessage
    ].freeze

    DEFERRED_TABLES = %w[
      users
      universe_memberships
      drafts
      draft_changes
      draft_change_outcomes
      review_requests
      notifications
      api_tokens
      api_token_universes
    ].freeze

    # The side of each join table that belongs to this universe. Filtering by one
    # side is enough: both sides of these joins are already scoped by the loader's
    # own rules, and a cross-scope row is corruption rather than data to preserve.
    JOIN_TABLES = {
      "characters_character_tags" => "character_id",
      "characters_factions" => "character_id",
      "events_event_tags" => "event_id",
      "factions_faction_tags" => "faction_id",
      "items_item_tags" => "item_id",
      "locations_location_tags" => "location_id",
      "ownerships_ownership_tags" => "ownership_id",
      "plots_scenes" => "plot_id",
      "relations_relation_tags" => "relation_id",
      "scene_element_speakers" => "scene_element_id",
      "scenes_scene_tags" => "scene_id",
      "sections_section_tags" => "section_id"
    }.freeze

    JOIN_COLUMN_MODELS = {
      "character_id" => Character,
      "event_id" => Event,
      "faction_id" => Faction,
      "item_id" => Item,
      "location_id" => Location,
      "ownership_id" => Ownership,
      "plot_id" => Plot,
      "relation_id" => Relation,
      "scene_element_id" => SceneElement,
      "scene_id" => Scene,
      "section_id" => Section
    }.freeze

    PhotoFile = Data.define(:path, :bytes, :missing)

    attr_reader :universe

    def initialize(universe)
      @universe = universe
    end

    def files
      @files ||= begin
        dumped = CORE_MODELS.to_h do |name|
          model = name.constantize
          [ "data/#{model.table_name}.yml", rows_for(model) ]
        end
        dumped["data/photos.yml"] = photo_rows
        dumped.merge(join_rows).transform_values { |rows| yaml_file(rows) }
      end
    end

    def counts
      @counts ||= files.transform_keys { |path| File.basename(path, ".yml") }.transform_values do |content|
        YAML.safe_load(content) || []
      end.transform_values(&:size)
    end

    def photo_files
      @photo_files ||= photos.filter_map do |photo|
        next add_missing_photo(photo) unless photo.file.attached?

        blob = photo.file.blob
        PhotoFile.new(path: archive_path(photo, blob), bytes: blob.download, missing: nil)
      end
    end

    def missing_photo_files
      photo_files.select(&:missing).map { |file| file.missing }
    end

    def deferred_tables
      DEFERRED_TABLES
    end

    private
      def rows_for(model)
        scoped_records(model).map { |record| attributes_for(record) }
      end

      def scoped_records(model)
        return model.unscoped.where(id: universe.id) if model == Universe
        return model.unscoped.where(universe_id: universe.id) if model.column_names.include?("universe_id")
        return model.unscoped.where(story_id: story_ids) if model.column_names.include?("story_id")
        return model.unscoped.where(scene_id: scene_ids) if model.column_names.include?("scene_id")
        return model.unscoped.where(scene_element_id: scene_element_ids) if model.column_names.include?("scene_element_id")
        return model.unscoped.where(discussion_id: discussion_ids) if model.column_names.include?("discussion_id")

        raise ArgumentError, "#{model.name} has no universe, story, scene, element, or discussion scope"
      end

      def story_ids
        @story_ids ||= Story.unscoped.where(universe_id: universe.id).select(:id)
      end

      def scene_ids
        @scene_ids ||= Scene.unscoped.where(story_id: story_ids).select(:id)
      end

      def scene_element_ids
        @scene_element_ids ||= SceneElement.unscoped.where(scene_id: scene_ids).select(:id)
      end

      def discussion_ids
        @discussion_ids ||= Discussion.unscoped.where(universe_id: universe.id).select(:id)
      end

      def photo_rows
        photos.map do |photo|
          attributes_for(photo).merge(
            "archive_path" => photo.file.attached? ? archive_path(photo, photo.file.blob) : nil,
            "file_name" => photo.file.attached? ? photo.file.filename.to_s : nil,
            "content_type" => photo.file.attached? ? photo.file.blob.content_type : nil,
            "byte_size" => photo.file.attached? ? photo.file.blob.byte_size : nil,
            "checksum" => photo.file.attached? ? photo.file.blob.checksum : nil
          )
        end
      end

      def photos
        @photos ||= Photo.unscoped.where(universe_id: universe.id).order(:id).to_a
      end

      def join_rows
        JOIN_TABLES.to_h do |table, column|
          ids = scoped_records(JOIN_COLUMN_MODELS.fetch(column)).pluck(:id)
          [ "data/#{table}.yml", select_join_rows(table, column, ids) ]
        end
      end

      def select_join_rows(table, column, ids)
        return [] if ids.empty?

        # Arel quotes the ids and the two names, so nothing in this query is a
        # string built from data. `ORDER BY 1, 2` is the join table's own column
        # order, which is the order the dump wants and needs no column names.
        join_table = Arel::Table.new(table)
        query = join_table.project(Arel.star)
          .where(join_table[column].in(ids))
          .order(Arel.sql("1, 2"))

        connection.select_all(query).to_a
      end

      def connection
        ActiveRecord::Base.connection
      end

      def attributes_for(record)
        record.attributes.transform_values do |value|
          if !value.is_a?(String) && value.respond_to?(:iso8601)
            value.iso8601
          else
            value
          end
        end
      end

      def yaml_file(rows)
        "# #{rows.first&.keys&.join(", ") || "no rows"}\n" + YAML.dump(rows)
      end

      def archive_path(photo, blob)
        "photos/#{photo.slug}-#{photo.id}#{extension_for(blob)}"
      end

      def extension_for(blob)
        extension = File.extname(blob.filename.to_s)
        return extension if extension.present?

        {
          "image/jpeg" => ".jpg",
          "image/png" => ".png",
          "image/gif" => ".gif",
          "image/webp" => ".webp"
        }.fetch(blob.content_type, ".bin")
      end

      def add_missing_photo(photo)
        PhotoFile.new(path: nil, bytes: nil, missing: photo.slug)
      end
  end
end
