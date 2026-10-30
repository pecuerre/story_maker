module CharactersHelper
  # The Character's Markdown description as safe HTML, with `[[kind:slug]]`
  # references resolved to links inside its own Universe. The service owns the
  # Markdown dialect and the reference rules; this is only the view's entry
  # point, so a second surface cannot invent a different rendering.
  def character_description_html(character)
    CharacterDescription.new(character.universe, character.description).to_html
  end

  # "Label: value" descriptions of the filters currently in effect, in the order
  # the search area lists them. The result set of a large universe is otherwise
  # ambiguous, and an empty result has to be able to say what caused it.
  #
  # Each entry is its own key rather than one frame with the field name
  # interpolated, because "Sort: Recently edited" is a different sentence in each
  # language than "Tag: House / Winter" is.
  #
  # The sort is described rather than omitted because a reader who reordered the
  # list and got nothing back needs to know that the order was applied and was
  # not the reason the list is short.
  def character_filter_summaries(filter)
    summaries = []
    summaries << t("characters.filter.summaries.search", value: filter.text) if filter.text.present?
    if filter.character_tag
      summaries << t("characters.filter.summaries.tag", value: @character_tag_paths.label_for(filter.character_tag))
    end
    summaries << t("characters.filter.summaries.sort", value: t("characters.filter.sort_options.#{filter.sort}")) if filter.sort != CharacterFilter::DEFAULT_SORT
    summaries
  end

  # The tag options the filter's selector offers, in root-first order. Built from
  # the paths rather than the flat query order so a child cannot appear before
  # its parent after a reparent or position edit.
  def character_filter_tag_choices
    @character_tag_paths.choices
  end
end
