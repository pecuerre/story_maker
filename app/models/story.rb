class Story < ApplicationRecord
  include HasSlug

  belongs_to :universe
  has_many :sections, dependent: :destroy
  has_many :section_tags, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :universe_id }
  validates :slug, uniqueness: { scope: :universe_id }
end
