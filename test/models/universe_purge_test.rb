require "test_helper"

# A permanent universe delete is judged by what is left behind, not by the
# universe row alone. `test/controllers/universe_purges_controller_test.rb`
# proves who may ask and what the confirmation must be; this file walks the
# ownership graph after the purge and fails on any row that still names the
# universe, its stories, or their scenes.
class UniversePurgeTest < ActiveSupport::TestCase
  # The HABTM join tables and both endpoints of each. Active Record removes a
  # join row when either side is destroyed, so an orphan here means one of the
  # two records outlived the purge.
  JOIN_TABLES = {
    "characters_character_tags" => %w[ character_id character_tag_id ],
    "characters_factions" => %w[ character_id faction_id ],
    "events_event_tags" => %w[ event_id event_tag_id ],
    "factions_faction_tags" => %w[ faction_id faction_tag_id ],
    "items_item_tags" => %w[ item_id item_tag_id ],
    "locations_location_tags" => %w[ location_id location_tag_id ],
    "ownerships_ownership_tags" => %w[ ownership_id ownership_tag_id ],
    "plots_scenes" => %w[ plot_id scene_id ],
    "relations_relation_tags" => %w[ relation_id relation_tag_id ],
    "scene_element_speakers" => %w[ scene_element_id character_id ],
    "scenes_scene_tags" => %w[ scene_id scene_tag_id ],
    "sections_section_tags" => %w[ section_id section_tag_id ]
  }.freeze

  setup do
    @universe = universes(:universe_one)
  end

  test "a purge removes the universe, every descendant, and every join row" do
    # Soft delete some of the content first. A soft-deleted row is invisible to
    # the default scope, which is exactly why the ordinary `dependent: :destroy`
    # cascade cannot reach it; the purge must take it anyway.
    stories(:story_one).soft_delete
    characters(:character_one).soft_delete
    factions(:faction_one).soft_delete
    locations(:location_one).soft_delete
    events(:event_one).soft_delete
    items(:item_one).soft_delete

    gone = ids_that_will_be_purged
    universe_id = @universe.id

    @universe.purge!

    assert_not Universe.exists?(universe_id)
    assert_no_universe_rows(universe_id)
    assert_no_scoped_rows(gone)
    assert_no_join_rows(gone)
  end

  test "a purge takes pending work, conversations, token links, and photos" do
    user = users(:user_one)
    draft = Draft.create!(user: user, universe: @universe)
    change = draft.draft_changes.create!(action: "create", record_type: "Character",
      payload: { "name" => "Pending", "universe_id" => @universe.id })
    DraftChangeOutcome.create!(draft: draft, draft_change: change, state: "written")
    review = ReviewRequest.create!(draft: draft, universe: @universe, submitted_by: user)

    discussion = Discussion.create!(universe: @universe, record: characters(:character_one), title: "Talk")
    message = discussion.messages.create!(user: user, body: "Hello")

    token = ApiToken.create!(user: user, name: "Purge token", token_digest: "digest", token_prefix: "purgetok")
    ApiTokenUniverse.create!(api_token: token, universe: @universe)
    photo = create_photo(universe: @universe)

    @universe.purge!

    assert_not Draft.exists?(draft.id)
    assert_not DraftChange.exists?(change.id)
    assert_equal 0, DraftChangeOutcome.where(draft_id: draft.id).count
    assert_not ReviewRequest.exists?(review.id)
    assert_not Discussion.exists?(discussion.id)
    assert_equal 0, DiscussionMessage.where(discussion_id: discussion.id).count
    assert_equal 0, ApiTokenUniverse.where(universe_id: @universe.id).count
    assert_not Photo.exists?(photo.id)
    assert ApiToken.exists?(token.id), "the token belongs to its account, not to the universe"
  end

  test "a purge does not touch another universe's records" do
    other = universes(:universe_two)
    other_character_ids = Character.with_deleted.where(universe_id: other.id).pluck(:id)

    @universe.purge!

    assert other.reload
    assert_equal other_character_ids.sort, Character.with_deleted.where(universe_id: other.id).pluck(:id).sort
  end

  private
    def connection
      ActiveRecord::Base.connection
    end

    # Every id the purge is expected to remove, collected before it runs and
    # through raw SQL so a soft-deleted row is included. The keys are table
    # names, which is what the join-table assertions look up by foreign key.
    def ids_that_will_be_purged
      ids = {}
      scoped_columns.each do |table, (column, values)|
        ids[table] = select_ids(table, column, values)
      end
      ids
    end

    # The scope a table is reached through, in the order the graph is walked.
    # `universe_id` covers almost everything; story- and scene-owned rows carry
    # no universe column of their own.
    def scoped_columns
      story_ids = select_ids("stories", "universe_id", @universe.id)
      scene_ids = select_ids("scenes", "story_id", story_ids)
      scene_element_ids = select_ids("scene_elements", "scene_id", scene_ids)
      discussion_ids = select_ids("discussions", "universe_id", @universe.id)
      draft_ids = select_ids("drafts", "universe_id", @universe.id)

      scoped = tables_with_column("universe_id").to_h { |table| [ table, [ "universe_id", @universe.id ] ] }
      tables_with_column("story_id").each { |table| scoped[table] = [ "story_id", story_ids ] }
      tables_with_column("scene_id").each { |table| scoped[table] = [ "scene_id", scene_ids ] }
      tables_with_column("scene_element_id").each { |table| scoped[table] = [ "scene_element_id", scene_element_ids ] }
      tables_with_column("discussion_id").each { |table| scoped[table] = [ "discussion_id", discussion_ids ] }
      tables_with_column("draft_id").each { |table| scoped[table] = [ "draft_id", draft_ids ] }
      scoped
    end

    # Join tables carry the same foreign-key column names but no primary key of
    # their own, so only a table with an `id` can be checked by id.
    def tables_with_column(column)
      connection.tables.select do |table|
        connection.column_exists?(table, column) && connection.column_exists?(table, "id")
      end
    end

    def select_ids(table, column, values)
      quoted_table = connection.quote_table_name(table)
      quoted_column = connection.quote_column_name(column)
      values = Array(values).map(&:to_i)

      return [] if values.empty?

      connection.select_values(
        "SELECT id FROM #{quoted_table} WHERE #{quoted_column} IN (#{values.join(', ')})",
        "Universe purge ids"
      ).map(&:to_i)
    end

    def assert_no_universe_rows(universe_id)
      tables_with_column("universe_id").each do |table|
        count = connection.select_value(
          "SELECT COUNT(*) FROM #{connection.quote_table_name(table)} WHERE universe_id = #{universe_id.to_i}"
        ).to_i

        assert_equal 0, count, "#{table} still has a row for the purged universe"
      end
    end

    # A scoped table is checked by the ids it held before the purge rather than
    # by a column value that no longer exists on the parent.
    def assert_no_scoped_rows(gone)
      gone.each do |table, ids|
        next if ids.empty?

        count = connection.select_value(
          "SELECT COUNT(*) FROM #{connection.quote_table_name(table)} WHERE id IN (#{ids.join(', ')})"
        ).to_i

        assert_equal 0, count, "#{table} still holds #{count} row(s) of the purged universe"
      end
    end

    def assert_no_join_rows(gone)
      JOIN_TABLES.each do |table, columns|
        columns.each do |column|
          owner_table = column.delete_suffix("_id").pluralize
          ids = gone[owner_table]
          next if ids.blank?

          count = connection.select_value(
            "SELECT COUNT(*) FROM #{connection.quote_table_name(table)} " \
            "WHERE #{connection.quote_column_name(column)} IN (#{ids.join(', ')})"
          ).to_i

          assert_equal 0, count, "#{table}.#{column} still names a purged #{owner_table} row"
        end
      end
    end
end
