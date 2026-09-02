class Story < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :section_types, dependent: :destroy

  before_validation :set_slug, if: :name_changed?

  def to_param
    slug
  end

  private

  def set_slug
    self.slug = name.to_s.parameterize.presence || SecureRandom.hex(4)
  end
end
