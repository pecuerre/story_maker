class Story < ApplicationRecord
  belongs_to :owner, class_name: "User"

  def to_param
    self.slug
  end
end
