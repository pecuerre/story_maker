class RelationType < ApplicationRecord
  include Hierarchical
  include HasColor

  belongs_to :story
  has_many :relations, dependent: :destroy

  validates :name, presence: true
  validates :inverse, presence: true, unless: :symmetric?
end