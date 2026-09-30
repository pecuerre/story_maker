# Builds the display paths for one Story's Section tree without an N+1 query.
#
# A Scene's grouping label and the Section selector both need a Section's full
# ancestor path. Preloading an arbitrary depth is not possible with `includes`,
# and `Section#ancestor_chain` would query once per level per Scene, so callers
# pass one ordered Section list (`position, id`) and every path is assembled in
# memory from a single query.
#
# Ordering follows the supplied array, so a child always follows its parent.
#
# `UNGROUPED_LABEL_KEY` is a key and not a translated string. A constant that
# called `t()` would be resolved once, in whatever locale happened to load this
# class first, and every later request would render that one language — the rule
# `ModalFields` and `TagsHelper` already follow. The label is resolved per
# request through `#ungrouped_label` instead.
class SectionPaths
  SEPARATOR = " / "
  UNGROUPED_LABEL_KEY = "sections.ungrouped_label"

  def self.build(sections)
    new(sections)
  end

  def initialize(sections)
    @by_parent = Array(sections).group_by(&:parent_id)
    @labels = {}
    @grouping_options = [ [ ungrouped_label, "" ] ]

    collect(nil, [], [], 0)
  end

  # Every Section id this index knows, in tree order. The Scenes list uses it to
  # validate a filter value against the Story's own tree without a second query.
  def ids
    @labels.keys
  end

  # The label of the group that is not a Section. The Scenes list badge, the
  # Section selector in the Scene editor, the Scenes filter, and the Sections
  # workspace's ungrouped block all read it from here, so there is one word for
  # the group rather than one per surface.
  # `SectionPaths` is a plain value object and does not include the view's
  # `translate` helper, so this reads the locale through `I18n.t` directly — the
  # same call, against the request's `I18n.locale`.
  def ungrouped_label
    I18n.t(UNGROUPED_LABEL_KEY)
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
