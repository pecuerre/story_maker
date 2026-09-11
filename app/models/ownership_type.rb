class OwnershipType < ApplicationRecord
  include Hierarchical
  include HasColor

  belongs_to :story
  has_many :ownerships, dependent: :destroy

  validates :name, presence: true
end
