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
end
