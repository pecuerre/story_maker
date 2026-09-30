# An optional `name` for a record whose identity is something else.
#
# `Relation` and `Ownership` are links between two other records, so their
# endpoints are the reliable label and the name is optional. Two consequences
# follow from that optionality, and both belong here rather than in each model:
#
# - A blank or whitespace-only name is stored as NULL, so "no name" has one
#   representation in the column, in the serialized editor values, and in a
#   demo-data manifest.
# - A name that has no slug of its own does not re-address the record.
#   `HasSlug#set_slug` regenerates the slug on every name change, and resolves a
#   blank or unslugifiable name to a random hex — so clearing a name, or renaming
#   to "!!!", would replace a meaningful address with an arbitrary one and discard
#   the composite slug these two models' endpoints and demo-data references depend
#   on. Renaming to a name that does slugify still renames; anything else leaves
#   the slug alone.
module OptionalName
  extend ActiveSupport::Concern

  included do
    # Before `HasSlug`, so it sees the name this decides on. `prepend` because the
    # models that include this also register their own prepended callbacks.
    before_validation :normalize_optional_name, prepend: true
    # After `HasSlug`, because that is the callback whose regenerated slug has to be
    # undone. It is registered without `prepend` and this concern is included after
    # `HasSlug`, so it runs second.
    before_validation :keep_slug_when_name_cleared
  end

  private
    def normalize_optional_name
      self.name = name.is_a?(String) ? name.strip.presence : name

      return if new_record?

      # A name that no longer has a slug of its own — because it was cleared, or
      # because it cannot be slugified at all — must not re-address the record.
      # `HasSlug` resolves both cases to a random hex, and for these two models
      # that would also discard a composite slug their endpoints and demo-data
      # references depend on.
      return if name.present? && self.class.slugify(name).present?
      return unless will_save_change_to_name?

      @slug_before_name_cleared = slug
    end

    # The slug this save started from, put back after `HasSlug` replaced it with a
    # random one. Assigned rather than left alone because it is a real change the
    # callback made, so dirty tracking sees it correctly.
    def keep_slug_when_name_cleared
      return if @slug_before_name_cleared.blank?

      self.slug = @slug_before_name_cleared
    ensure
      remove_instance_variable(:@slug_before_name_cleared) if defined?(@slug_before_name_cleared)
    end
end
