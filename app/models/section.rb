class Section < ApplicationRecord
  include Hierarchical
  include HasManyTypes
  include HasSlug

  belongs_to :story
  has_many_types :section_type

  validates :name, presence: true
end
