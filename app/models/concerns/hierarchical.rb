module Hierarchical
  extend ActiveSupport::Concern

  included do
    belongs_to :parent, class_name: name, optional: true
    has_many :children, -> { order(:position, :id) },
             class_name: name,
             foreign_key: :parent_id,
             dependent: :destroy

    validate :parent_belongs_to_same_universe
    validate :parent_cannot_be_self
    validate :parent_cannot_be_descendant
  end

  def root?
    parent_id.nil?
  end

  def sibling_scope
    hierarchy_scope.public_send(self.class.table_name).where(parent_id: parent_id).where.not(id: id).order(:position, :id)
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

  # Ownership scope parents must share. Defaults to the universe; models that
  # belong to something narrower (Section belongs_to :story) override these.
  def hierarchy_scope
    universe
  end

  def hierarchy_scope_attribute
    :universe_id
  end

  def hierarchy_scope_error
    "must belong to the same universe"
  end

  def parent_belongs_to_same_universe
    return if parent.nil? ||
      parent.public_send(hierarchy_scope_attribute) == public_send(hierarchy_scope_attribute)

    errors.add(:parent, hierarchy_scope_error)
  end

  def parent_cannot_be_self
    errors.add(:parent, "cannot be itself") if parent.present? && parent == self
  end

  def parent_cannot_be_descendant
    return if parent.nil? || new_record? || parent_id == id

    errors.add(:parent, "cannot be a descendant") if parent.ancestor_chain.include?(self)
  end
end
