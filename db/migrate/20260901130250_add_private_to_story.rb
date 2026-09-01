class AddPrivateToStory < ActiveRecord::Migration[8.1]
  def change
    add_column :stories, :private, :boolean, default: false
  end
end
