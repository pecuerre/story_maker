class Taxon < ApplicationRecord
  belongs_to :taxonomy
  belongs_to :parent, class_name: "Taxon", optional: true

  has_many :children, class_name: "Taxon", foreign_key: "parent_id", dependent: :destroy

  validates :name, presence: true
  validates :taxonomy, presence: true

  scope :roots, -> { where(parent: nil) }
  scope :children, -> { where.not(parent: nil) }

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
