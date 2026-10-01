class EventTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug
  include HasPhoto
  include SoftDeletable
  include Searchable

  searchable kind: "tag", title: :name, body: :description, route: "event_tag", taxonomy: "Event"
  soft_deletes :children

  belongs_to :universe
  has_many_tagged :event, scope: :universe_id

  validates :name, presence: true
end
