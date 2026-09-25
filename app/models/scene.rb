# A Scene is one narrative unit inside a Story. Stories own the ordered scene
# sequence; universe-level world records stay shared and are linked to a scene
# in later slices. The sequence is flat: `position` expresses narrative order,
# not in-world chronology, and is maintained by PositionedResourceOrder.
class Scene < ApplicationRecord
  include HasSlug
  include InvalidatesMenuCounts

  invalidates_menu_counts_for :story, cache_scope: Story::SCENE_MENU_COUNT_SCOPE

  belongs_to :story

  validates :name, presence: true

  def universe
    story&.universe
  end
end
