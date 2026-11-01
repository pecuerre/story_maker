module CanonRulesHelper
  # The fields the modal pre-fills when a row is opened for editing. It must name
  # exactly the controls the editor renders — `test/controllers/modal_json_contract_test.rb`
  # compares the two lists, because a field missing here opens empty and a key
  # here with no field submits a value nobody chose.
  def canon_rule_fields_json(rule)
    {
      name: rule.name,
      slug: rule.slug,
      category: rule.category,
      canon_type: rule.canon_type,
      statement: rule.statement,
      source: rule.source,
      story_id: rule.story_id
    }.to_json
  end

  # The canon type selector, label beside stored value. The list is the model's
  # own constant, so a new type is added in one place and the editor, the row,
  # and the details page all show it.
  def canon_type_options
    CanonRule::CANON_TYPES.map { |type| [ t("canon_rules.canon_type.#{type}"), type ] }
  end

  # A rule's type as the badge text a row and a details page show, or nil when
  # the rule carries none.
  def canon_type_label(rule)
    t("canon_rules.canon_type.#{rule.canon_type}") if rule.canon_type.present?
  end

  # A rule's stable address, shown the way the ledger writes it: an imported id
  # (`k1`, `l2`) reads as `K1`, `L2`, so a row and a citation in prose use the
  # same label. A slug derived from a name is not a ledger id and is shown as
  # stored.
  def canon_rule_id(rule)
    rule.slug.match?(/\A[a-z]\d+\z/) ? rule.slug.upcase : rule.slug
  end

  # The statement or the source passage as the details page renders it: the
  # shared Markdown dialect, so the author's paragraphs, lists, emphasis, and
  # `[[kind:slug]]` references are read the same way a Character's description is.
  # A rule may be long — an imported item's whole text — which is why the details
  # page, not the row, is where the format is interpreted.
  def canon_rule_prose_html(text)
    MarkdownDescription.new(Current.universe, text).to_html
  end

  # The statement or the source passage as a list row shows it: one line of
  # plain text, with a `[[canon:K1]]` reference reduced to the id it names and no
  # link at all. The row already carries its own Details link, and a second one
  # inside a two-line preview competes with it — the same treatment a Character
  # or Faction summary gets.
  def canon_rule_prose(text)
    MarkdownDescription.new(Current.universe, text).as_plain_text
  end

  # "Label: value" descriptions of the filters currently in effect, in the order
  # the search area lists them. The result set of a large universe is otherwise
  # ambiguous, and an empty result has to be able to say what caused it.
  #
  # The sort is described rather than omitted because a reader who reordered the
  # list and got nothing back needs to know that the order was applied and was
  # not the reason the list is short.
  def canon_rule_filter_summaries(filter)
    summaries = []
    summaries << t("canon_rules.filter.summaries.search", value: filter.text) if filter.text.present?
    if filter.canon_type.present?
      summaries << t("canon_rules.filter.summaries.canon_type",
        value: t("canon_rules.canon_type.#{filter.canon_type}"))
    end
    if filter.universe_wide?
      summaries << t("canon_rules.filter.summaries.scope",
        value: t("canon_rules.scope.universe"))
    elsif filter.story
      summaries << t("canon_rules.filter.summaries.scope", value: filter.story.name)
    end
    if filter.sort != CanonRuleFilter::DEFAULT_SORT
      summaries << t("canon_rules.filter.summaries.sort",
        value: t("canon_rules.filter.sort_options.#{filter.sort}"))
    end
    summaries
  end
end
