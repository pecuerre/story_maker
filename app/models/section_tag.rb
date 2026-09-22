class SectionTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug

  belongs_to :universe
  has_many_tagd :section

  validates :name, presence: true
end
