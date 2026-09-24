module HasManyTags
  extend ActiveSupport::Concern

  class_methods do
    # Declares a many-to-many relationship to a taxonomy "tag" model, e.g.
    # `has_many_tags :character_tag, scope: :universe_id` on Character.
    # on Character. Backed by a habtm join table named "<element_table>_<tag_table>".
    # Tags are never required: a record may be saved untagged (a simple story just wants
    # a few characters/locations/sections, no taxonomy needed). The association is
    # always restricted to the same universe (or story for section-scoped records),
    # and the same-scope check is repeated as a model validation for ID writers.
    def has_many_tags(tag_name, scope:)
      association = tag_name.to_s.pluralize.to_sym

      declare_scoped_habtm(
        association,
        scope: scope,
        class_name: tag_name.to_s.camelize,
        join_table: "#{table_name}_#{tag_name.to_s.pluralize}"
      )
    end

    # Declares the inverse side on a "tag" model, e.g.
    # `has_many_tagd :character, scope: :universe_id` on CharacterTag.
    def has_many_tagd(element_name, scope:)
      association = element_name.to_s.pluralize.to_sym

      declare_scoped_habtm(
        association,
        scope: scope,
        class_name: element_name.to_s.camelize,
        join_table: "#{element_name.to_s.pluralize}_#{table_name}"
      )
    end

    private
      def declare_scoped_habtm(association, scope:, **options)
        has_and_belongs_to_many association,
          ->(owner) { where(scope => owner.public_send(scope)) },
          **options

        validate do
          public_send(association).each do |record|
            next if record.public_send(scope) == public_send(scope)

            errors.add(association, "must belong to the same #{scope.to_s.delete_suffix('_id')}")
          end
        end
      end
  end
end
