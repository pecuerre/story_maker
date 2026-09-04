class RelationType < ApplicationRecord
  belongs_to :story
  include Hierarchical

  validates :name, presence: true
  validates :inverse, presence: true, unless: :symmetric?
end