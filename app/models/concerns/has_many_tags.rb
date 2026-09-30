module HasManyTags
  extend ActiveSupport::Concern

  class_methods do
    # The inverse side a tag model uses to list the records carrying it, e.g.
    # `:characters` on `CharacterTag`. A content model that only declares
    # `has_many_tags` has no inverse side and returns nil.
    def tagged_records_association
      @tagged_records_association
    end

    # The scope attribute a declared tag association is restricted to, e.g.
    # :universe_id on Character, :story_id on SectionTag.
    def tagged_records_scope_attribute
      @tagged_records_scope_attribute
    end

    # The tag association declared on this model, on either side (:character_tags
    # on Character, :characters on CharacterTag). Distinct from
    # tagged_records_association, which is only set on the tag side.
    def tagged_records_join_association
      @tagged_records_join_association
    end

    # The I18n **key** of the sentence that says a tagged record must share this
    # model's scope, chosen from the scope attribute the declaration passed.
    #
    # It was one interpolated string here, which spliced the scope's own word into
    # a fixed frame — a locale that contracts or genders its determiner with that
    # noun cannot be handed a frame, so the two scopes are two sentences now. The
    # key is resolved per validation rather than frozen here, so a request is
    # answered in its own language; see `features/i18n.md`.
    def tag_scope_error_key(scope)
      case scope.to_s.delete_suffix("_id")
      when "universe" then "shared.errors.same_scope.universe"
      when "story" then "shared.errors.same_scope.story"
      else raise ArgumentError, "no scope sentence for #{scope.inspect}"
      end
    end

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
      @tagged_records_association = association

      declare_scoped_habtm(
        association,
        scope: scope,
        class_name: element_name.to_s.camelize,
        join_table: "#{element_name.to_s.pluralize}_#{table_name}"
      )
    end

    private
      def declare_scoped_habtm(association, scope:, **options)
        @tagged_records_scope_attribute = scope
        @tagged_records_join_association = association

        has_and_belongs_to_many association,
          ->(owner) { where(scope => owner.public_send(scope)) },
          **options

        validate do
          public_send(association).each do |record|
            next if record.public_send(scope) == public_send(scope)

            errors.add(association, I18n.t(self.class.tag_scope_error_key(scope)))
          end
        end

        validate :scope_change_does_not_orphan_join_rows
      end
  end

  # The records carrying this tag, for the tag's own details page. It is the
  # scoped inverse association, so it can never disclose a record from another
  # universe or story. A content model has no inverse side and returns none.
  def tagged_records
    association = self.class.tagged_records_association
    return self.class.none if association.nil?

    public_send(association).reorder(:name, :id)
  end

  # The records carrying this tag or any of its descendants. Used when the
  # "include child tags" toggle is enabled on the tag details page. Queries
  # the join table directly with all descendant tag IDs to avoid N+1 queries.
  def tagged_records_including_descendants
    association = self.class.tagged_records_association
    return self.class.none if association.nil?

    reflection = self.class.reflect_on_association(association)
    return self.class.none unless reflection

    tag_ids = [ id, *descendant_ids ]
    return self.class.none if tag_ids.empty?

    element_class = reflection.klass
    join_table = reflection.join_table
    element_fk = reflection.association_foreign_key
    tag_fk = reflection.foreign_key
    scope_attr = self.class.tagged_records_scope_attribute
    scope_value = public_send(scope_attr)

    element_class
      .joins("INNER JOIN #{join_table} ON #{join_table}.#{element_fk} = #{element_class.table_name}.id")
      .where(join_table => { tag_fk => tag_ids })
      .where(scope_attr => scope_value)
      .distinct
      .reorder(:name, :id)
  end

  # A tag assignment links this record to another record through a join table.
  # Changing the owning scope (universe, or story for section-scoped records)
  # would leave those join rows pointing across scopes, which violates the
  # graph-wide scope rules, so a scope change is rejected while assignment rows
  # exist. The scoped association read cannot detect them: after the change it
  # only matches records that already share the new scope.
  def scope_change_does_not_orphan_join_rows
    scope = self.class.tagged_records_scope_attribute
    return unless scope && persisted?
    return unless will_save_change_to_attribute?(scope)
    return unless join_rows_exist?

    errors.add(scope, I18n.t("shared.errors.tagged_records.scope_change_with_tags"))
  end

  private

  def join_rows_exist?
    association = self.class.tagged_records_join_association
    reflection = association && self.class.reflect_on_association(association)
    return false unless reflection

    count = self.class.connection.select_value(
      "SELECT COUNT(*) FROM #{reflection.join_table} WHERE #{reflection.foreign_key} = #{id}"
    )
    count.to_i > 0
  end
end
