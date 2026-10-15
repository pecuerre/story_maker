# Narrows the story's canonical Scene list without changing what that list is.
#
# `Scene#position` stays the only order: a filter never reorders, regroups, or
# renumbers a scene, and the story's scene total is counted from the whole
# sequence rather than from the rows a filter happens to return. This is the one
# working `ListFilter`, and the shared contract it inherits is in
# [`docs/features/list_filters.md`](../docs/features/list_filters.md).
#
# `UNGROUPED` is a **value** and never changes with the locale, because it is
# what travels in the `section_id` query parameter. Only the label printed beside
# it is chrome, and that comes from `SectionPaths#ungrouped_label`.
#
# Query contract for `GET /u/:universe_slug/s/:story_id/scenes`:
#
#   `q`             free text over the scene title and short description
#   `section_id`    a Section of this story, or `UNGROUPED` for scenes with none
#   `scene_tag_id`  a Scene Tag of this story: the author's label for a scene
#   `from`, `to`    inclusive in-world days, applied to the scene's own datetime
#
# A value that cannot be used — an id from another story, an unreadable date — is
# dropped instead of silently emptying the list, and every drop is reported in
# `discarded` so the page can say what it ignored.
class SceneFilter < ListFilter
  # Section ids are integers, so this value cannot collide with one and keeps
  # "ungrouped" distinct from "no section filter".
  UNGROUPED = "ungrouped"
  PARAMS = %i[ q section_id scene_tag_id from to ].freeze

  attr_reader :section_id, :from_date, :to_date, :scene_tag

  # `section_ids` and `scene_tags` are the story-scoped lists the index already
  # loaded, so a filter value is validated against them without another query and
  # a foreign id can never reach the query.
  #
  # `section_id` is the Section the list narrowed to, or nil when it did not
  # narrow to one; the ungrouped group is reported by `ungrouped?` because it has
  # no Section.
  def initialize(params, section_ids:, scene_tags:)
    @section_ids = section_ids
    @scene_tags = scene_tags
    super(params)
  end

  def ungrouped?
    group_value == UNGROUPED
  end

  # The resolved Scene Tag id, used by the query string and by the selected
  # option.
  def scene_tag_id
    scene_tag&.id
  end

  # The story's scenes, still in narrative order, narrowed by the active filters.
  # The order is the last thing applied, and it is the only order.
  def apply(relation)
    relation = narrowed_by_tag(relation, scene_tag)
    relation = narrowed_by_text(relation, table: "scenes", columns: %w[ name description ])
    relation = narrowed_by_group(relation)
    relation = narrowed_by_day_range(relation, :datetime, from: from_date, to: to_date)
    relation.reorder(:position, :id)
  end

  # The filter as canonical query keys, so a link or a redirect can carry exactly
  # the filters that are really in effect. A dropped value is not carried over.
  def query_params
    query = {}
    query[:q] = text if text.present?
    query[:section_id] = group_value if group_value.present?
    query[:scene_tag_id] = scene_tag.id.to_s if scene_tag
    query[:from] = from_date.iso8601 if from_date
    query[:to] = to_date.iso8601 if to_date
    query
  end

  private
    def resolve
      resolve_text
      @group_value = resolve_group_value(@params[:section_id])
      @section_id = group_value == UNGROUPED ? nil : group_value&.to_i
      @scene_tag = resolve_in_list(@params[:scene_tag_id], @scene_tags,
        "scenes.filter.discarded.scene_tag", identifier: :id)
      @from_date = resolve_day(@params[:from],
        label_key: "scenes.filter.bound.start",
        discard_key: "scenes.filter.discarded.date")
      @to_date = resolve_day(@params[:to],
        label_key: "scenes.filter.bound.end",
        discard_key: "scenes.filter.discarded.date")
    end

    # The ungrouped group is a value rather than a Section, so it is resolved
    # before the list is asked whether the value names a Section of this story.
    def resolve_group_value(value)
      raw = value.to_s.strip
      return if raw.blank?
      return UNGROUPED if raw == UNGROUPED

      resolve_in_list(raw, @section_ids, "scenes.filter.discarded.section")&.to_s
    end

    def narrowed_by_group(relation)
      return relation.where(section_id: nil) if ungrouped?
      return relation if section_id.nil?

      relation.where(section_id: section_id)
    end

    attr_reader :group_value
end
