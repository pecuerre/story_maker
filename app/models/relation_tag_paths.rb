# Builds readable paths for the universe's Relation Tag hierarchy without walking
# parent associations for every Relation. This is the same value-object shape as
# `CharacterTagPaths`, `SceneTagPaths`, and `LocationPaths`: one ordered list in,
# every root-first ancestor path out, so the Relations filter can offer and label
# a tag by the path a reader recognizes rather than by a leaf name that another
# branch may repeat.
#
# The list is ordered by (position, id), so roots and their children remain
# stable in the filter's tag selector after a reparent or position edit.
class RelationTagPaths
  SEPARATOR = " / "

  def self.build(tags)
    new(tags)
  end

  def initialize(tags)
    @by_parent = Array(tags).group_by(&:parent_id)
    @labels = {}
    @choices = []

    collect(nil, [], [])
  end

  # Accepts a RelationTag or tag id. Returns nil for an unknown id.
  def label_for(tag_or_id)
    id = tag_or_id.respond_to?(:id) ? tag_or_id.id : tag_or_id
    return if id.blank?

    @labels[id]
  end

  # [ label, id ] pairs in root-first order. This is intentionally separate from
  # the caller's flat query order so a child cannot appear before its parent in
  # the filter's tag selector after a reparent or position edit.
  def choices
    @choices.dup
  end

  private
    def collect(parent_id, path, visited)
      (@by_parent[parent_id] || []).each do |tag|
        # The model prevents cycles, but keep this value object safe for a
        # corrupt/imported row while it is being displayed.
        next if visited.include?(tag.id)

        label = ([ *path, tag.name ]).join(SEPARATOR)
        @labels[tag.id] = label
        @choices << [ label, tag.id ]
        collect(tag.id, path + [ tag.name ], visited + [ tag.id ])
      end
    end
end
