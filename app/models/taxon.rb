class Taxon < ApplicationRecord
  include HasParentAndChildren

  belongs_to :taxonomy
  belongs_to :parent, class_name: "Taxon", optional: true

  has_many :children, class_name: "Taxon", foreign_key: "parent_id", dependent: :destroy

  validates :name, presence: true
  validates :taxonomy, presence: true
end
