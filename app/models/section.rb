class Section < ApplicationRecord
  belongs_to :story
  belongs_to :section_type
  include Hierarchical

  validates :name, presence: true
end
