# Narrows the story's canonical Scene list without changing what that list is.
#
# `Scene#position` stays the only order: a filter never reorders, regroups, or
# renumbers a scene, and the story's scene total is counted from the whole
# sequence rather than from the rows a filter happens to return. It is a value
# object — it reads only the query keys in `PARAMS` and never assigns them to a
# model — so the Scenes index stays a plain HTML GET.
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
class SceneFilter
  # Section ids are integers, so this value cannot collide with one and keeps
  # "ungrouped" distinct from "no section filter".
  UNGROUPED = "ungrouped"
  PARAMS = %i[ q section_id scene_tag_id from to ].freeze

  attr_reader :text, :section_id, :from_date, :to_date, :scene_tag, :discarded

  # `section_ids` and `scene_tags` are the story-scoped lists the index already
  # loaded, so a filter value is validated against them without another query and
  # a foreign id can never reach the query.
  #
  # `section_id` is the Section the list narrowed to, or nil when it did not
  # narrow to one; the ungrouped group is reported by `ungrouped?` because it has
  # no Section.
  def initialize(params, section_ids:, scene_tags:)
    @discarded = []
    @text = params[:q].to_s.strip
    @group_value = resolve_group_value(params[:section_id], section_ids)
    @section_id = @group_value == UNGROUPED ? nil : @group_value&.to_i
    @scene_tag = resolve_scene_tag(params[:scene_tag_id], scene_tags)
    @from_date = resolve_date("start", params[:from])
    @to_date = resolve_date("end", params[:to])
  end

  def ungrouped?
    @group_value == UNGROUPED
  end

  # The resolved Scene Tag id, used by the query string and by the selected
  # option.
  def scene_tag_id
    scene_tag&.id
  end

  def active?
    query_params.any?
  end

  # The story's scenes, still in narrative order, narrowed by the active filters.
  def apply(relation)
    relation = narrowed_by_tag(relation)
    relation = narrowed_by_text(relation) if text.present?
    relation = narrowed_by_group(relation)
    relation = narrowed_by_in_world_range(relation) if from_date || to_date
    relation.reorder(:position, :id)
  end

  # The filter as canonical query keys, so a link or a redirect can carry exactly
  # the filters that are really in effect. A dropped value is not carried over.
  def query_params
    query = {}
    query[:q] = text if text.present?
    query[:section_id] = @group_value if @group_value.present?
    query[:scene_tag_id] = scene_tag.id.to_s if scene_tag
    query[:from] = from_date.iso8601 if from_date
    query[:to] = to_date.iso8601 if to_date
    query
  end

  private
    def resolve_group_value(value, section_ids)
      raw = value.to_s.strip
      return if raw.blank?
      return UNGROUPED if raw == UNGROUPED

      id = section_ids.find { |candidate| candidate.to_s == raw }
      return id.to_s if id

      @discarded << t("scenes.filter.discarded.section")
      nil
    end

    def resolve_scene_tag(value, scene_tags)
      raw = value.to_s.strip
      return if raw.blank?

      tag = scene_tags.find { |candidate| candidate.id.to_s == raw }
      return tag if tag

      @discarded << t("scenes.filter.discarded.scene_tag")
      nil
    end

    # A `date` input submits an ISO day or nothing, so an unreadable value only
    # arrives from a hand-edited URL. It is reported, not guessed at.
    #
    # `bound` names the end of the range, and it is a key rather than the literal
    # `start`/`end` this method is called with: the word the reader sees is the one
    # beside the control they used, so it comes from `scenes.filter.bound.*`.
    def resolve_date(bound, value)
      raw = value.to_s.strip
      return if raw.blank?

      Date.iso8601(raw)
    rescue Date::Error
      @discarded << t("scenes.filter.discarded.date",
        bound: t("scenes.filter.bound.#{bound}"), value: raw)
      nil
    end

    # The scoped inverse association is the only way to reach the scenes carrying
    # a tag, so a tag filter can never disclose another story's scenes.
    def narrowed_by_tag(relation)
      return relation if scene_tag.nil?

      relation.where(id: scene_tag.tagged_records.select(:id))
    end

    # SQLite's LIKE ignores ASCII case, which is what a search box needs here.
    # `%` and `_` are escaped with an explicit ESCAPE character, so an author's
    # literal text is searched for instead of being read as a pattern.
    def narrowed_by_text(relation)
      pattern = "%#{Scene.sanitize_sql_like(text)}%"

      relation.where(<<~SQL.squish, pattern: pattern)
        scenes.name LIKE :pattern ESCAPE '\\'
        OR scenes.description LIKE :pattern ESCAPE '\\'
      SQL
    end

    def narrowed_by_group(relation)
      return relation.where(section_id: nil) if ungrouped?
      return relation if section_id.nil?

      relation.where(section_id: section_id)
    end

    # The bounds are days, not instants, and both are inclusive. A scene without
    # an in-world time is excluded while a bound is set: it has no time to
    # compare, and a null datetime is never inside a range.
    def narrowed_by_in_world_range(relation)
      if from_date && to_date
        relation.where(datetime: from_date.beginning_of_day..to_date.end_of_day)
      elsif from_date
        relation.where(datetime: from_date.beginning_of_day..)
      else
        relation.where(datetime: ..to_date.end_of_day)
      end
    end

    # `SceneFilter` is a value object and does not include the view's `translate`
    # helper, so these keys resolve through `I18n.t` against the request's
    # `I18n.locale` — the same call `Event`'s own `errors.add` messages make. The
    # alternative, storing keys and letting the view translate them, would mean
    # the controller had to know which of the filter's internal labels are chrome.
    def t(key, **options)
      I18n.t(key, **options)
    end
end
