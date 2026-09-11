module HasManyTypes
  extend ActiveSupport::Concern

  class_methods do
    # Declares a many-to-many relationship to a taxonomy "type" model, e.g. `has_many_types :character_type`
    # on Character. Backed by a habtm join table named "<element_table>_<type_table>".
    def has_many_types(type_name, required: true)
      association = type_name.to_s.pluralize.to_sym

      has_and_belongs_to_many association,
        class_name: type_name.to_s.camelize,
        join_table: "#{table_name}_#{type_name.to_s.pluralize}"

      validates association, presence: true if required
    end

    # Declares the inverse side on a "type" model, e.g. `has_many_typed :character` on CharacterType.
    def has_many_typed(element_name)
      association = element_name.to_s.pluralize.to_sym

      has_and_belongs_to_many association,
        class_name: element_name.to_s.camelize,
        join_table: "#{element_name.to_s.pluralize}_#{table_name}"
    end
  end
end
