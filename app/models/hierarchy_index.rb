# One query's worth of a hierarchy: the rows a tree renders, indexed by parent.
#
# Every taxonomy page draws the same tree, and `shared/_taxonomy_node` descends
# one level per row. Rails cannot preload an unknown depth, so `includes(:children)`
# reached only the first level and the second level onwards asked the database once
# per parent row — twice per row, in fact, because `children.any?` on an unloaded
# association counts separately from the `children.each` that follows it. The
# content trees asked again for every deeper node's tags.
#
# A caller loads the hierarchy's rows once and this answers every level from
# memory. Ordering is `position, id`, the order `Hierarchical`'s own `children`
# scope and every tree's root query use, so a row cannot move by being reached
# through the index instead of through its association.
#
# This is the same value-object shape as `SectionPaths`, `SceneTagPaths`, and
# `LocationPaths`: one ordered list in, every derived answer out.
class HierarchyIndex
  NO_CHILDREN = [].freeze

  def self.build(records)
    new(records)
  end

  def initialize(records)
    @records = records.to_a.sort_by { |record| [ record.position, record.id ] }
    @by_parent = @records.group_by(&:parent_id)
  end

  # Every row with no parent, in the order the tree starts from.
  def roots
    children_of(nil)
  end

  # A record's children, in the same order, or an empty list for a leaf. Takes a
  # record or a bare id, and returns the shared empty list rather than a new one so
  # a leaf costs nothing.
  def children_of(record_or_id)
    id = record_or_id.respond_to?(:parent_id) ? record_or_id.id : record_or_id
    @by_parent.fetch(id, NO_CHILDREN)
  end

  # Every row this index knows, ordered. A parent selector or an editor descriptor
  # that needs the whole hierarchy reads it from here instead of issuing its own
  # query for a list this page has already loaded.
  def records
    @records
  end
end
