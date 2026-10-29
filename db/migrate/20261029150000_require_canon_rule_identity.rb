class RequireCanonRuleIdentity < ActiveRecord::Migration[8.1]
  # The record's name and slug were nullable only while the rows written before
  # ADR 0045 were still waiting for the story-interchange source to replace them.
  # The development data has been re-imported, so the table can now enforce what
  # the model already requires.
  def change
    change_column_null :canon_rules, :slug, false
    change_column_null :canon_rules, :name, false
  end
end
