class Section < ApplicationRecord
  include Hierarchical

  belongs_to :story
  belongs_to :section_type

  validates :name, presence: true
end
