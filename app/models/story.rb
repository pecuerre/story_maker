class Story < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :section_types, dependent: :destroy

  def to_param
    self.slug
  end
end
