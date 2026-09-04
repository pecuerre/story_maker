class LocationType < ApplicationRecord
  belongs_to :story
  belongs_to :parent, class_name: "LocationType", optional: true
  has_many :children, -> { order(:position, :id) },
           class_name: "LocationType",
           foreign_key: :parent_id,
           dependent: :destroy
  has_many :locations, dependent: :destroy

  validates :name, presence: true
  validate :parent_belongs_to_same_story
  validate :parent_cannot_be_self
  validate :parent_cannot_be_descendant

  def root?
    parent_id.nil?
  end

  def sibling_scope
    story.location_types.where(parent_id: parent_id).where.not(id: id).order(:position, :id)
  end

  def ancestor_chain
    node = parent
    result = []
    visited = []

    while node && !visited.include?(node)
      result << node
      visited << node
      node = node.parent
    end

    result
  end

  private

  def parent_belongs_to_same_story
    return if parent.nil? || parent.story_id == story_id

    errors.add(:parent, "must belong to the same story")
  end

  def parent_cannot_be_self
    errors.add(:parent, "cannot be itself") if parent.present? && parent == self
  end

  def parent_cannot_be_descendant
    return if parent.nil? || new_record? || parent_id == id

    errors.add(:parent, "cannot be a descendant") if parent.ancestor_chain.include?(self)
  end
end
