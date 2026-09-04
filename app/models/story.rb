class Story < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :section_types, dependent: :destroy
  has_many :sections, dependent: :destroy
  has_many :item_types, dependent: :destroy
  has_many :items, dependent: :destroy
  has_many :location_types, dependent: :destroy
  has_many :locations, dependent: :destroy
  has_many :character_types, dependent: :destroy
  has_many :characters, dependent: :destroy

  before_validation :set_slug, if: :name_changed?

  def to_param
    slug
  end

  private

  def set_slug
    self.slug = name.to_s.parameterize.presence || SecureRandom.hex(4)
  end
end
