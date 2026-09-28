# Character, Location, Item, and Event tags can be pinned to their workspace
# tab strip. A tag with `show_in_menu: true` appears as a tab beside the
# content tabs and links to that tag's own details page — the same view the
# taxonomy tree's Details link opens. Relation, Ownership, Section, and Scene
# tags do not get this field: their workspaces have no tab strip to pin to.
class AddShowInMenuToContentTags < ActiveRecord::Migration[8.1]
  CONTENT_TAG_TABLES = %w[
    character_tags
    location_tags
    item_tags
    event_tags
  ].freeze

  def change
    CONTENT_TAG_TABLES.each do |table|
      add_column table, :show_in_menu, :boolean, default: false, null: false
    end
  end
end
