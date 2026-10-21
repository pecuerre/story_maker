module RelationsHelper
  # "Label: value" descriptions of the filters currently in effect, in the order
  # the search area lists them. The result set of a large universe is otherwise
  # ambiguous, and an empty result has to be able to say what caused it.
  #
  # Each entry is its own key rather than one frame with the field name
  # interpolated, because "Relation tag: House / Winter" is a different sentence
  # in each language than "Search: “Ariadne”" is.
  #
  # The sort is described rather than omitted because a reader who reordered the
  # list and got nothing back needs to know that the order was applied and was
  # not the reason the list is short.
  def relation_filter_summaries(filter)
    summaries = []
    summaries << t("relations.filter.summaries.search", value: filter.text) if filter.text.present?
    if filter.relation_tag
      summaries << t("relations.filter.summaries.tag", value: @relation_tag_paths.label_for(filter.relation_tag))
    end
    summaries << t("relations.filter.summaries.sort", value: t("relations.filter.sort_options.#{filter.sort}")) if filter.sort != RelationFilter::DEFAULT_SORT

    summaries
  end

  # The tag options the filter's selector offers, in root-first order. Built from
  # the paths rather than the flat query order so a child cannot appear before
  # its parent after a reparent or position edit.
  def relation_filter_tag_choices
    @relation_tag_paths.choices
  end

  # The readable sentence a relation list row renders: the two characters as
  # subjects and the relation tag as the verb, with the arrow as direction.
  # `Character one — Relation tag one → Character two`. Tags are optional, so a
  # relation without one falls back to the neutral endpoints form
  # `Character one → Character two`. No new source fields: the tag name and the
  # endpoints already exist, only the presentation changes.
  def relation_row_sentence(relation)
    verb = relation.relation_tags.first&.name
    if verb.present?
      "#{relation.character1.name} — #{verb} → #{relation.character2.name}"
    else
      "#{relation.character1.name} → #{relation.character2.name}"
    end
  end
end
