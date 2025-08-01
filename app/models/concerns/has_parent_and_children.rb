module HasParentAndChildren
  extend ActiveSupport::Concern

  included do
    scope :roots, -> { where(parent: nil) }
    scope :children, -> { where.not(parent: nil) }
  end

  def root?
    parent.nil?
  end

  def leaf?
    children.empty?
  end

  def ancestors
    return [] if root?
    [ parent ] + parent.ancestors
  end

  def self_and_ancestors
    [ self ] + ancestors
  end

  def descendants
    children.map { |child| [ child ] + child.descendants }.flatten
  end

  def self_and_descendants
    [ self ] + descendants
  end

  def depth
    ancestors.size
  end

  def full_path
    self_and_ancestors.reverse.map(&:name).join(" > ")
  end
end
