class Ownership < ApplicationRecord
  include HasManyTags
  include HasSlug
  include InvalidatesMenuCounts

  invalidates_menu_counts_for :universe

  belongs_to :universe
  belongs_to :item
  belongs_to :character
  has_many_tags :ownership_tag, scope: :universe_id

  # Generate before HasSlug so the composite slug can be set on create.
  # Later endpoint or tag changes do not rewrite this creation-time snapshot.
  before_validation :generate_slug, on: :create, prepend: true
  validates :item, :character, presence: true
  validate :associated_records_belong_to_universe

  private

  def generate_slug
    return if slug.present?

    if name.present?
      name_slug = slugify(name)
      return self.slug = name_slug if name_slug.present?
    end

    # Tags are optional, so the tag segment may be missing entirely.
    parts = [ character&.slug, ownership_tags.first&.slug, item&.slug ].compact
    self.slug = parts.presence&.join("-") || SecureRandom.hex(4)
  end

  def associated_records_belong_to_universe
    { item: item, character: character }.each do |name, record|
      errors.add(name, "must belong to the ownership's universe") if record && universe && record.universe_id != universe_id
    end
  end
end
