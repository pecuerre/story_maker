class Location < ApplicationRecord
  include HasParentAndChildren

  belongs_to :story
  belongs_to :location_type, class_name: "Taxon", foreign_key: "location_type_taxon_id", optional: true
  belongs_to :parent, class_name: "Location", optional: true

  has_many :children, class_name: "Location", foreign_key: "parent_id", dependent: :destroy

  validates :name, presence: true
end
