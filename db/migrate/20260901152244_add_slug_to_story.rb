class AddSlugToStory < ActiveRecord::Migration[8.1]
  def change
    add_column :stories, :slug, :string
  end
end
