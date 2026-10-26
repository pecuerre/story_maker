class AddPronounsAndAliasesToCharacters < ActiveRecord::Migration[8.1]
  def change
    add_column :characters, :pronouns, :string
    add_column :characters, :aliases, :text
  end
end
