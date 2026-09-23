class Ownership < ApplicationRecord
  include HasManyTags
  include HasSlug
  include InvalidatesMenuCounts

  invalidates_menu_counts_for :universe

  belongs_to :universe
  belongs_to :item
  belongs_to :character
  has_many_tags :ownership_tag

  before_validation :generate_slug, on: :create
  validates :item, :character, presence: true
  validate :associated_records_belong_to_universe

  private

  def generate_slug
    return if slug.present?

    if name.present?
      self.slug = name.to_s.parameterize
      return
    end

    # Tags are optional, so the tag segment may be missing entirely.
    parts = [ character&.slug, ownership_tags.first&.slug, item&.slug ].compact
    self.slug = parts.presence&.join("-") || SecureRandom.hex(4)
  end

  def associated_records_belong_to_universe
    { item: item, character: character }.each do |name, record|
      errors.add(name, "must belong to the ownership's universe") if record && universe && record.universe_id != universe_id
    end
    ownership_tags.each do |ownership_tag|
      next if universe.nil? || ownership_tag.universe_id == universe_id

      errors.add(:ownership_tags, "must belong to the ownership's universe")
    end
  end
end
