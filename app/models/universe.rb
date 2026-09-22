class Universe < ApplicationRecord
  include HasSlug

  scope :visible_to, ->(user) {
    user ? where(private: false).or(where(owner_id: user.id)) : where(private: false)
  }

  belongs_to :owner, class_name: "User"
  has_many :stories, dependent: :destroy
  has_many :section_tags, dependent: :destroy
  has_many :sections, through: :stories
  has_many :item_tags, dependent: :destroy
  has_many :items, dependent: :destroy
  has_many :location_tags, dependent: :destroy
  has_many :locations, dependent: :destroy
  has_many :character_tags, dependent: :destroy
  has_many :characters, dependent: :destroy
  has_many :relation_tags, dependent: :destroy
  has_many :relations, dependent: :destroy
  has_many :ownership_tags, dependent: :destroy
  has_many :ownerships, dependent: :destroy
  has_many :event_tags, dependent: :destroy
  has_many :events, dependent: :destroy

  def to_param
    slug
  end
end
