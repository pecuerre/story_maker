class Section < ApplicationRecord
  belongs_to :story
  belongs_to :section_type
  belongs_to :parent, class_name: "Section", optional: true
  has_many :children,
           class_name: "Section",
           foreign_key: :parent_id,
           dependent: :destroy

  validates :name, presence: true
end
