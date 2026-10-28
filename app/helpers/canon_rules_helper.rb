module CanonRulesHelper
  # The fields the modal pre-fills when a row is opened for editing. It must name
  # exactly the controls the editor renders — `test/controllers/modal_json_contract_test.rb`
  # compares the two lists, because a field missing here opens empty and a key
  # here with no field submits a value nobody chose.
  def canon_rule_fields_json(rule)
    {
      statement: rule.statement,
      source: rule.source,
      story_id: rule.story_id
    }.to_json
  end
end
