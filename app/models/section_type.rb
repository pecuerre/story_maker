class SectionType < ApplicationRecord
  include Hierarchical

  belongs_to :story
  has_many :sections, dependent: :destroy

  validates :name, presence: true
end
