class SectionType < ApplicationRecord
  belongs_to :story
  has_many :sections, dependent: :destroy
  include Hierarchical

  validates :name, presence: true
end
