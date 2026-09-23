module HasManyTags
  extend ActiveSupport::Concern

  class_methods do
    # Declares a many-to-many relationship to a taxonomy "tag" model, e.g. `has_many_tags :character_tag`
    # on Character. Backed by a habtm join table named "<element_table>_<tag_table>".
    # Tags are never required: a record may be saved untagged (a simple story just wants
    # a few characters/locations/sections, no taxonomy needed).
    def has_many_tags(tag_name)
      association = tag_name.to_s.pluralize.to_sym

      has_and_belongs_to_many association,
        class_name: tag_name.to_s.camelize,
        join_table: "#{table_name}_#{tag_name.to_s.pluralize}"
    end

    # Declares the inverse side on a "tag" model, e.g. `has_many_tagd :character` on CharacterTag.
    def has_many_tagd(element_name)
      association = element_name.to_s.pluralize.to_sym

      has_and_belongs_to_many association,
        class_name: element_name.to_s.camelize,
        join_table: "#{element_name.to_s.pluralize}_#{table_name}"
    end
  end
end
