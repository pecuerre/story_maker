class EventTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug
  include Searchable
  searchable kind: "tag", title: :name, body: :description, route: "event_tag", taxonomy: "Event"

  belongs_to :universe
  has_many_tagd :event, scope: :universe_id

  validates :name, presence: true
end
