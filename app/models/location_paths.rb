# Builds readable paths for one Universe's Location hierarchy without walking
# parent associations for every row.
#
# A Scene may use any number of Locations, and those Locations nest: "Jonas
# Room" means nothing without "Jonas House" and "Winden". Preloading an arbitrary
# depth is not possible with `includes`, and `Location#ancestor_chain` would
# query once per level per row, so callers pass one ordered Location list
# (`position, id`) and every path is assembled in memory from a single query.
#
# This is the same value-object shape as `SectionPaths` and `SceneTagPaths`:
# the picker offers indented names, while a linked row shows its full ancestor
# path so two places with the same name are never ambiguous.
class LocationPaths
  SEPARATOR = " / "
  INDENT = "— "

  def self.build(locations)
    new(locations)
  end

  def initialize(locations)
    @by_parent = Array(locations).group_by(&:parent_id)
    @labels = {}
    @choices = []

    collect(nil, [], [], 0)
  end

  # Accepts a Location or a location id. Returns the bare name for a top-level
  # place and nil for an id this universe's tree does not contain.
  def label_for(location_or_id)
    id = location_or_id.respond_to?(:id) ? location_or_id.id : location_or_id
    return if id.blank?

    @labels[id]
  end

  # [ label, id ] pairs in root-first order, with a child always after its parent
  # and depth-indented so a nested place is recognizable in a flat picker. This is
  # intentionally separate from the caller's query order so a child cannot appear
  # before its parent in the selector after a reparent or position edit.
  def choices
    @choices.dup
  end

  private
    def collect(parent_id, path, visited, depth)
      (@by_parent[parent_id] || []).each do |location|
        # The model prevents cycles, but keep this value object safe for a
        # corrupt/imported row while it is being displayed.
        next if visited.include?(location.id)

        label = ([ *path, location.name ]).join(SEPARATOR)
        @labels[location.id] = label
        @choices << [ (INDENT * depth) + location.name, location.id ]
        collect(location.id, path + [ location.name ], visited + [ location.id ], depth + 1)
      end
    end
end
