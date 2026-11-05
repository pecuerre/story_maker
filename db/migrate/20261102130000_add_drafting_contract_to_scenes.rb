class AddDraftingContractToScenes < ActiveRecord::Migration[8.1]
  def change
    add_column :scenes, :drafting_contract, :text
  end
end
