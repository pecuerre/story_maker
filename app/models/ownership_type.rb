class OwnershipType < ApplicationRecord
  include Hierarchical

  belongs_to :story
  has_many :ownerships, dependent: :destroy

  validates :name, presence: true
end
