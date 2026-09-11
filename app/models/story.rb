class Story < ApplicationRecord
  include HasSlug

  belongs_to :owner, class_name: "User"
  has_many :section_types, dependent: :destroy
  has_many :sections, dependent: :destroy
  has_many :item_types, dependent: :destroy
  has_many :items, dependent: :destroy
  has_many :location_types, dependent: :destroy
  has_many :locations, dependent: :destroy
  has_many :character_types, dependent: :destroy
  has_many :characters, dependent: :destroy
  has_many :relation_types, dependent: :destroy
  has_many :relations, dependent: :destroy
  has_many :ownership_types, dependent: :destroy
  has_many :ownerships, dependent: :destroy
  has_many :event_types, dependent: :destroy
  has_many :events, dependent: :destroy

  def to_param
    slug
  end
end
