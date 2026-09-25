require "pathname"
require "yaml"

module Development
  class UniverseDataLoader
    class Error < StandardError; end
    class EnvironmentError < Error; end
    class ValidationError < Error; end

    REFERENCE_PATTERN = /\A([A-Z][A-Za-z0-9_]*)\.([A-Za-z0-9_-]+)\z/
    VIRTUAL_ATTRIBUTES = {
      "User" => %w[password password_confirmation]
    }.freeze
    UNIVERSE_ASSOCIATION_FIELDS = %w[
      character1
      character2
      item
      character
      before_event
      after_event
      simultaneous_event
    ].freeze

    Record = Struct.new(
      :definition,
      :attributes,
      :identifier,
      :source_index,
      :resolved_attributes,
      :loaded_record,
      keyword_init: true
    )

    attr_reader :universe, :environment

    def initialize(universe:, root: Rails.root, environment: nil, verbose: true)
      @universe = UniverseDataRegistry.normalize_universe(universe)
      @root = Pathname(root)
      @environment_override = !environment.nil?
      @environment = (environment || Rails.env).to_s
      @verbose = verbose
    end

    def self.check!(universe:, validate_schema: true, **options)
      new(universe: universe, **options).check!(validate_schema: validate_schema)
    end

    def self.load!(**options)
      new(**options).load!
    end

    def check!(validate_schema: true)
      validate_environment_override!
      ensure_check_environment!
      validate_universe_name!
      validate_catalog!
      @records = read_records(validate_schema: validate_schema)
      validate_target_universe!
      resolve_references!
      validate_scopes!
      validate_position_metadata!
      self
    end

    def load!
      validate_environment_override!
      ensure_load_environment!
      check!

      unless Universe.table_exists?
        raise ValidationError, "Database schema is not prepared; run bin/rails db:prepare before loading development data"
      end

      if Universe.exists?(slug: target_identifier)
        raise ValidationError, "Universe '#{target_identifier}' already exists; run db:demo:reset before loading it again"
      end

      ApplicationRecord.transaction(requires_new: true) do
        @records.each { |record| create_record(record) }
        normalize_positions!
      end
      Rails.cache.clear
      self
    end

    private
      def validate_environment_override!
        return unless @environment_override
        return if Rails.env.test?

        raise EnvironmentError, "The Rails environment cannot be overridden outside the test environment"
      end

      def ensure_check_environment!
        return if %w[development test].include?(environment)

        raise EnvironmentError, "Development data checks are allowed only in development or test (current environment: #{environment})"
      end

      def ensure_load_environment!
        return if environment == "development"

        raise EnvironmentError, "Development data can only be loaded in development (current environment: #{environment})"
      end

      def validate_universe_name!
        UniverseDataRegistry.directory_name_for(universe)
      rescue KeyError => error
        raise ValidationError, error.message
      end

      def validate_catalog!
        UniverseDataRegistry.validate_directories!(@root)
      rescue KeyError => error
        raise ValidationError, error.message
      end

      def target_identifier
        @target_identifier ||= Universe.slugify(universe)
      end

      def data_root
        @data_root ||= @root.join("db/data")
      end

      def universe_directory
        @universe_directory ||= data_root.join(UniverseDataRegistry.directory_name_for(universe))
      end

      def read_records(validate_schema:)
        unless universe_directory.directory?
          raise ValidationError, "Development universe directory not found: #{universe_directory}"
        end

        expected_files = UniverseDataRegistry.file_names.map { |file_name| "#{file_name}.yml" }
        entries = universe_directory.children
        symlinked_entries = entries.select(&:symlink?).map { |path| path.basename.to_s }
        if symlinked_entries.any?
          raise ValidationError, "Development data entries must not be symlinks: #{symlinked_entries.join(', ')}"
        end

        nested_directories = entries.select(&:directory?).map { |path| path.basename.to_s }
        if nested_directories.any?
          raise ValidationError, "Development universe directories must not contain nested directories: #{nested_directories.join(', ')}"
        end

        actual_files = entries.select(&:file?).map { |path| path.basename.to_s }
        missing_files = expected_files - actual_files
        unexpected_files = actual_files - expected_files
        if missing_files.any? || unexpected_files.any?
          details = []
          details << "missing: #{missing_files.join(', ')}" if missing_files.any?
          details << "unexpected: #{unexpected_files.join(', ')}" if unexpected_files.any?
          raise ValidationError, "Invalid data files in #{universe_directory}: #{details.join('; ')}"
        end

        UniverseDataRegistry.definitions.flat_map do |definition|
          path = universe_directory.join("#{definition.file_name}.yml")
          attributes = read_yaml(path)

          attributes.each_with_index.map do |attribute_values, source_index|
            unless attribute_values.is_a?(Hash)
              raise ValidationError, "#{path}:#{source_index + 1} must contain a mapping"
            end

            attribute_values = attribute_values.transform_keys(&:to_s)
            validate_attribute_names!(definition, attribute_values, path, source_index, validate_schema: validate_schema)

            Record.new(
              definition: definition,
              attributes: attribute_values,
              identifier: identifier_for(definition, attribute_values),
              source_index: source_index,
              resolved_attributes: nil,
              loaded_record: nil
            )
          end
        end
      end

      def read_yaml(path)
        value = YAML.safe_load_file(path, aliases: true)
        if value.nil?
          raise ValidationError, "#{path} must contain an explicit YAML array (use [])"
        end

        unless value.is_a?(Array)
          raise ValidationError, "#{path} must contain a YAML array"
        end

        value
      rescue Psych::Exception => error
        raise ValidationError, "Could not parse #{path}: #{error.message}"
      end

      def validate_attribute_names!(definition, attributes, path, source_index, validate_schema:)
        model = definition.model

        attributes.each_key do |attribute|
          attribute = attribute.to_s
          if %w[id created_at updated_at].include?(attribute)
            raise ValidationError, "#{path}:#{source_index + 1} must not set #{attribute}"
          end

          if attribute.end_with?("_id") && model.reflect_on_association(attribute.delete_suffix("_id"))
            raise ValidationError, "#{path}:#{source_index + 1} must use the association name instead of #{attribute}"
          end
        end

        return unless validate_schema && model.table_exists?

        allowed_attributes = model.column_names + model.reflect_on_all_associations.map { |association| association.name.to_s } + VIRTUAL_ATTRIBUTES.fetch(definition.model_name, [])
        attributes.each_key do |attribute|
          next if allowed_attributes.include?(attribute.to_s)

          raise ValidationError, "#{path}:#{source_index + 1} has unknown #{model.name} attribute '#{attribute}'"
        end
      end

      def identifier_for(definition, attributes)
        value = attributes["slug"]
        value = attributes["title"] if value.blank? && definition.model_name == "Event"
        value = attributes["name"] if value.blank?
        return if value.blank?

        normalized_identifier(definition, value)
      end

      def normalized_identifier(definition, value)
        return unless definition.model.respond_to?(:slugify)

        definition.model.slugify(value)
      end

      def validate_target_universe!
        universe_records = records_for_model("Universe")
        if universe_records.empty?
          raise ValidationError, "#{universe_directory}/universes.yml must define a universe"
        end

        identifiers = universe_records.map(&:identifier)
        unless identifiers.include?(target_identifier)
          raise ValidationError, "Universe directory '#{universe}' must define a universe with slug '#{target_identifier}'"
        end

        unexpected = identifiers - [ target_identifier ]
        if unexpected.any?
          raise ValidationError, "Universe directory '#{universe}' contains another universe: #{unexpected.join(', ')}"
        end
      end

      def resolve_references!
        @records_by_reference = {}

        records_with_identifiers.each do |record|
          key = reference_key(record.definition.model_name, record.identifier)
          if @records_by_reference.key?(key)
            existing = @records_by_reference[key]
            raise ValidationError, "#{record_label(existing)} and #{record_label(record)} define duplicate #{record.definition.model_name}.#{record.identifier}"
          end

          @records_by_reference[key] = record
        end

        @records.each do |record|
          record.resolved_attributes = resolve_attributes(record.attributes, record)
        end
      end

      def resolve_attributes(attributes, record)
        attributes.each_with_object({}) do |(field, value), resolved|
          resolved[field] = resolve_value(value, record, field.to_s)
        end
      end

      def records_with_identifiers
        @records.select { |record| record.identifier.present? }
      end

      def records_for_model(model_name)
        @records.select { |record| record.definition.model_name == model_name }
      end

      def resolve_value(value, record, field)
        association = record.definition.model.reflect_on_association(field)
        return value unless association
        return if value.nil?

        if association.collection?
          unless value.is_a?(Array)
            raise ValidationError, "#{record_label(record)} field '#{field}' must be an array of Model.slug references"
          end

          return value.map { |item| resolve_association_value(item, record, field, association) }
        end

        resolve_association_value(value, record, field, association)
      end

      def resolve_association_value(value, record, field, association)
        unless value.is_a?(String) && value.match?(REFERENCE_PATTERN)
          raise ValidationError, "#{record_label(record)} field '#{field}' must use a Model.slug reference"
        end

        resolve_reference(value, record, association, field)
      end

      def resolve_reference(value, record, association = nil, field = nil)
        match = value.match(REFERENCE_PATTERN)
        return value unless match

        referenced_model_name = match[1]
        definition = UniverseDataRegistry.definition_for_model(referenced_model_name)
        unless definition
          raise ValidationError, "#{record_label(record)} uses unknown model in reference '#{value}'"
        end

        referenced_identifier = normalized_identifier(definition, match[2])
        unless referenced_identifier
          raise ValidationError, "#{record_label(record)} references #{value}, but #{referenced_model_name} has no stable identifier"
        end

        referenced_record = @records_by_reference[reference_key(referenced_model_name, referenced_identifier)]
        unless referenced_record
          raise ValidationError, "#{record_label(record)} references missing #{value}"
        end

        if association && referenced_record.definition.model_name != association.klass.name
          field_name = field || value
          raise ValidationError, "#{record_label(record)} field '#{field_name}' must reference #{association.klass.name}, not #{referenced_record.definition.model_name}"
        end

        current_definition_index = UniverseDataRegistry.model_names.index(record.definition.model_name)
        referenced_definition_index = UniverseDataRegistry.model_names.index(referenced_model_name)
        if referenced_definition_index > current_definition_index
          raise ValidationError, "#{record_label(record)} references #{value}, which is loaded in a later model file"
        end

        if referenced_model_name == record.definition.model_name && referenced_record.source_index >= record.source_index
          raise ValidationError, "#{record_label(record)} references #{value}, which must be defined earlier in the same file"
        end

        referenced_record
      end

      def validate_scopes!
        @records.each do |record|
          definition = record.definition

          case definition.scope
          when :universe
            validate_universe_scoped_record!(record)
          when :story
            validate_story_scoped_record!(record)
          end

          validate_parent_scope!(record)
          validate_tag_scopes!(record)
          validate_association_scopes!(record)
        end
      end

      def validate_universe_scoped_record!(record)
        if record.definition.model_name != "Universe" && !record.attributes.key?("universe")
          raise ValidationError, "#{record_label(record)} must declare its universe"
        end

        actual_universe = universe_for(record)
        return if actual_universe == target_identifier

        raise ValidationError, "#{record_label(record)} belongs to universe '#{actual_universe || "(none)"}', expected '#{target_identifier}'"
      end

      def validate_story_scoped_record!(record)
        unless record.attributes.key?("story")
          raise ValidationError, "#{record_label(record)} must declare its story"
        end

        actual_universe = universe_for(record)
        return if actual_universe == target_identifier

        raise ValidationError, "#{record_label(record)} belongs to universe '#{actual_universe || "(none)"}', expected '#{target_identifier}'"
      end

      def validate_parent_scope!(record)
        parent = record.resolved_attributes["parent"]
        return if parent.nil?

        if record.definition.scope == :story
          return if story_for(parent) == story_for(record)

          raise ValidationError, "#{record_label(record)} parent must belong to the same story"
        end

        return if universe_for(parent) == universe_for(record)

        raise ValidationError, "#{record_label(record)} parent must belong to the same universe"
      end

      def validate_tag_scopes!(record)
        record.resolved_attributes.each do |field, value|
          next unless field.end_with?("_tags")
          next unless value.is_a?(Array)

          value.each do |tag|
            unless tag.definition.model_name.end_with?("Tag")
              raise ValidationError, "#{record_label(record)} field '#{field}' must contain tag records"
            end

            if record.definition.scope == :story
              next if story_for(tag) == story_for(record)

              raise ValidationError, "#{record_label(record)} tag '#{tag.identifier}' must belong to the same story"
            end

            next if universe_for(tag) == universe_for(record)

            raise ValidationError, "#{record_label(record)} tag '#{tag.identifier}' must belong to the same universe"
          end
        end
      end

      def validate_association_scopes!(record)
        return unless record.definition.scope == :universe

        UNIVERSE_ASSOCIATION_FIELDS.each do |field|
          association = record.resolved_attributes[field]
          next if association.nil?
          next if universe_for(association) == universe_for(record)

          raise ValidationError, "#{record_label(record)} #{field} must belong to the same universe"
        end
      end

      def story_scoped_model?(model_name)
        UniverseDataRegistry.definition_for_model(model_name)&.scope == :story
      end

      def universe_for(record)
        return if record.nil?
        return record.identifier if record.definition.model_name == "Universe"
        return if record.definition.model_name == "User"
        return universe_for(record.resolved_attributes["story"]) if story_scoped_model?(record.definition.model_name)

        universe_for(record.resolved_attributes["universe"])
      end

      def story_for(record)
        return if record.nil?
        return unless story_scoped_model?(record.definition.model_name)

        record.resolved_attributes["story"]
      end

      def create_record(record)
        attributes = materialize(record.resolved_attributes)
        model = record.definition.model
        record.loaded_record = model.create!(attributes)
        puts "Created #{model.name}: #{record_label_for_output(record)}" if @verbose
      rescue ActiveRecord::RecordInvalid => error
        raise ValidationError, "#{record_label(record)} failed validation: #{error.record.errors.full_messages.to_sentence}"
      rescue ActiveRecord::RecordNotUnique => error
        raise ValidationError, "#{record_label(record)} conflicts with an existing record: #{error.message}"
      end

      def materialize(value)
        case value
        when Record
          value.loaded_record || raise(ValidationError, "Reference order prevented #{value.definition.model_name}.#{value.identifier} from loading")
        when Array
          value.map { |item| materialize(item) }
        when Hash
          value.transform_values { |item| materialize(item) }
        else
          value
        end
      end

      def validate_position_metadata!
        positioned_records = @records.select { |record| record.definition.positioned? }
        positioned_records.group_by { |record| static_position_group_key(record) }.each_value do |group|
          values = group.map { |record| record.attributes["position"] }
          next if values.all?(&:nil?)
          if values.any?(&:nil?)
            raise ValidationError, "#{group.first.definition.file_name}.yml must provide position for all siblings or none"
          end

          normalized_values = values.map { |value| normalize_position_value(value, group.first) }
          if normalized_values.uniq.length != normalized_values.length
            raise ValidationError, "#{group.first.definition.file_name}.yml contains duplicate sibling positions"
          end
        end
      end

      def static_position_group_key(record)
        parent = reference_identifier(record.resolved_attributes["parent"]) if record.definition.hierarchical_position?
        if story_scoped_model?(record.definition.model_name)
          story = reference_identifier(record.resolved_attributes["story"])
          [ record.definition.model_name, :story, story, parent ]
        else
          universe = reference_identifier(record.resolved_attributes["universe"])
          [ record.definition.model_name, :universe, universe, parent ]
        end
      end

      def reference_identifier(record)
        record&.identifier
      end

      def normalize_position_value(value, record)
        valid_integer = value.is_a?(Integer) || value.to_s.match?(/\A\d+\z/)
        raise ArgumentError unless valid_integer

        Integer(value)
      rescue ArgumentError, TypeError
        raise ValidationError, "#{record_label(record)} position must be a non-negative integer"
      end

      def normalize_positions!
        positioned_records = @records.select { |record| record.definition.positioned? && record.loaded_record }
        positioned_records.group_by { |record| position_group_key(record.loaded_record, record.definition) }.each_value do |group|
          ordered = ordered_position_records(group)
          ordered.each_with_index do |record, index|
            record.loaded_record.update_column(:position, index) unless record.loaded_record.position == index
          end
        end
      end

      def position_group_key(record, definition)
        scope = if story_scoped_model?(record.class.name)
          [ record.story_id, definition.hierarchical_position? ? record.parent_id : nil ]
        else
          [ record.universe_id, definition.hierarchical_position? ? record.parent_id : nil ]
        end

        [ record.class.name, *scope ]
      end

      def ordered_position_records(group)
        values = group.map { |record| record.attributes["position"] }
        return group.sort_by(&:source_index) if values.all?(&:nil?)
        if values.any?(&:nil?)
          raise ValidationError, "#{group.first.definition.file_name}.yml must provide position for all siblings or none"
        end

        group.sort_by { |record| [ record.attributes["position"].to_i, record.source_index ] }
      end

      def record_label(record)
        "#{record.definition.file_name}.yml:#{record.source_index + 1}"
      end

      def record_label_for_output(record)
        loaded_record = record.loaded_record
        return record.identifier || "record" unless loaded_record

        value = loaded_record.name if loaded_record.respond_to?(:name)
        value = loaded_record.title if value.blank? && loaded_record.respond_to?(:title)
        value = loaded_record.slug if value.blank? && loaded_record.respond_to?(:slug)
        value.presence || record.identifier || "record"
      end

      def reference_key(model_name, identifier)
        [ model_name, identifier ]
      end
  end
end
