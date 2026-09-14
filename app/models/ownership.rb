class Ownership < ApplicationRecord
  include HasManyTypes
  include HasSlug

  belongs_to :universe
  belongs_to :item
  belongs_to :character
  has_many_types :ownership_type

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

    self.slug = "#{character.slug}-#{ownership_types.first.slug}-#{item.slug}"
  end

  def associated_records_belong_to_universe
    { item: item, character: character }.each do |name, record|
      errors.add(name, "must belong to the ownership's universe") if record && universe && record.universe_id != universe_id
    end
    ownership_types.each do |ownership_type|
      next if universe.nil? || ownership_type.universe_id == universe_id

      errors.add(:ownership_types, "must belong to the ownership's universe")
    end
  end
end
