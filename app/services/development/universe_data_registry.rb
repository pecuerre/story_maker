require "pathname"

module Development
  class UniverseDataRegistry
    ModelDefinition = Struct.new(
      :model_name,
      :file_name,
      :scope,
      :positioned,
      :position_mode,
      keyword_init: true
    ) do
      def model
        model_name.constantize
      end

      def positioned?
        positioned
      end

      def hierarchical_position?
        position_mode.to_s != "flat"
      end
    end

    DEFINITIONS = [
      ModelDefinition.new(model_name: "User", file_name: "users", scope: :none),
      ModelDefinition.new(model_name: "Universe", file_name: "universes", scope: :universe),
      ModelDefinition.new(model_name: "UniverseMembership", file_name: "universe_memberships", scope: :universe),
      ModelDefinition.new(model_name: "Story", file_name: "stories", scope: :universe),
      ModelDefinition.new(model_name: "SectionTag", file_name: "section_tags", scope: :story, positioned: true),
      ModelDefinition.new(model_name: "Section", file_name: "sections", scope: :story, positioned: true),
      ModelDefinition.new(model_name: "LocationTag", file_name: "location_tags", scope: :universe, positioned: true),
      ModelDefinition.new(model_name: "Location", file_name: "locations", scope: :universe, positioned: true),
      ModelDefinition.new(model_name: "CharacterTag", file_name: "character_tags", scope: :universe, positioned: true),
      ModelDefinition.new(model_name: "Character", file_name: "characters", scope: :universe, positioned: true),
      ModelDefinition.new(model_name: "RelationTag", file_name: "relation_tags", scope: :universe, positioned: true),
      ModelDefinition.new(model_name: "Relation", file_name: "relations", scope: :universe),
      ModelDefinition.new(model_name: "ItemTag", file_name: "item_tags", scope: :universe, positioned: true),
      ModelDefinition.new(model_name: "Item", file_name: "items", scope: :universe, positioned: true),
      ModelDefinition.new(model_name: "OwnershipTag", file_name: "ownership_tags", scope: :universe, positioned: true),
      ModelDefinition.new(model_name: "Ownership", file_name: "ownerships", scope: :universe),
      ModelDefinition.new(model_name: "EventTag", file_name: "event_tags", scope: :universe, positioned: true),
      ModelDefinition.new(model_name: "Event", file_name: "events", scope: :universe, positioned: true),
      # Loaded after Event because a Scene may reference a shared universe
      # event; a symbolic reference may not point at a later model file.
      ModelDefinition.new(model_name: "Scene", file_name: "scenes", scope: :story, positioned: true, position_mode: :flat)
    ].freeze

    UNIVERSES = {
      "dark" => "dark",
      "lotr" => "lotr"
    }.freeze

    class << self
      def definitions
        DEFINITIONS
      end

      def model_names
        definitions.map(&:model_name)
      end

      def file_names
        definitions.map(&:file_name)
      end

      def definition_for_model(model_name)
        definitions.find { |definition| definition.model_name == model_name }
      end

      def normalize_universe(value)
        value.to_s.strip.downcase
      end

      def registered_universe?(value)
        UNIVERSES.key?(normalize_universe(value))
      end

      def directory_name_for(value)
        normalized = normalize_universe(value)
        UNIVERSES.fetch(normalized) do
          raise KeyError, "Unknown development universe #{normalized.presence || "(blank)"}. Registered universes: #{UNIVERSES.keys.join(', ')}"
        end
      end

      def validate_directories!(root)
        data_root = Pathname(root).join("db/data")
        entries = data_root.children
        symlinked_directories = entries.select(&:symlink?).map { |path| path.basename.to_s }
        raise KeyError, "Development data directories must not be symlinks: #{symlinked_directories.join(', ')}" if symlinked_directories.any?

        discovered = entries.select(&:directory?).map { |path| path.basename.to_s }.sort
        missing = UNIVERSES.keys - discovered
        unregistered = discovered - UNIVERSES.keys

        return if missing.empty? && unregistered.empty?

        details = []
        details << "missing registered directories: #{missing.join(', ')}" if missing.any?
        details << "unregistered directories: #{unregistered.join(', ')}" if unregistered.any?
        raise KeyError, "Development data catalog mismatch (#{details.join('; ')})"
      end
    end
  end
end
