# The one row of configuration that belongs to the platform rather than to a
# universe.
#
# A universe's own budgets are columns on `universes`, because a universe's admins
# own them. Universe *creation* is the one mutation with no universe yet: `POST /u`
# is read before the row exists, so there is nothing for its budget to hang on and
# nothing for an admin of some other universe to own. This table is that budget's
# home, and it holds exactly one number today.
#
# A singleton rather than a settings key-value table, because a key-value store
# would let a typo become a setting nobody reads and a lookup become a string
# comparison. One row, one column, one reader.
#
# `null: true` with a default of 5, for the same reason `universes.mutation_limit`
# is: every row is protected from the moment it exists, and `NULL` is the one value
# an operator can store to mean "no limit on this at all", which is a different
# setting from a number and would otherwise have nowhere to go.
#
# **No timestamps at all.** The row is written when an operator changes the number
# and read on every universe creation; nothing orders these rows, nothing reports
# when one was last touched, and nothing would notice their absence — so a
# `created_at` here would be a column with no reader, on a table that can only ever
# hold one row.
class CreatePlatformSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_settings do |t|
      t.integer :universe_creation_limit, default: 5, null: true
    end
  end
end
