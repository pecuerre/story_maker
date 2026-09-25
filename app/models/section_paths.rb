# Builds the display paths for one Story's Section tree without an N+1 query.
#
# A Scene's grouping label and the Section selector both need a Section's full
# ancestor path. Preloading an arbitrary depth is not possible with `includes`,
# and `Section#ancestor_chain` would query once per level per Scene, so callers
# pass one ordered Section list (`position, id`) and every path is assembled in
# memory from a single query.
#
# Ordering follows the supplied array, so a child always follows its parent.
class SectionPaths
  SEPARATOR = " / "
  UNGROUPED_LABEL = "Ungrouped"

  def self.build(sections)
    new(sections)
  end

  def initialize(sections)
    @by_parent = Array(sections).group_by(&:parent_id)
    @labels = {}
    @grouping_options = [ [ UNGROUPED_LABEL, "" ] ]

    collect(nil, [], [], 0)
  end

  # Accepts a Section or a section id. Returns nil when the Scene is ungrouped
  # or when the id is not part of this Story's tree.
  def label_for(section_or_id)
    id = section_or_id.respond_to?(:id) ? section_or_id.id : section_or_id
    return if id.blank?

    @labels[id]
  end

  # [ label, value ] pairs in Rails' select order: **Ungrouped** first, then
  # depth-indented Section names, a child always after its parent.
  def grouping_options
    @grouping_options.dup
  end

  private
    # `visited` guards against a corrupt parent cycle; `path` is the
    # root-first ancestor names used for the readable label.
    def collect(parent_id, visited, path, depth)
      (@by_parent[parent_id] || []).each do |section|
        next if visited.any? { |seen| seen.equal?(section) }

        @labels[section.id] = ([ *path, section.name ]).join(SEPARATOR)
        @grouping_options << [ ("— " * depth) + section.name, section.id ]
        collect(section.id, visited + [ section ], path + [ section.name ], depth + 1)
      end
    end
end
