# The three per-group ceilings, each in its own column beside `mutation_limit`.
#
# One bucket for every mutation turned out to be a blunt instrument: a burst of
# photo uploads and a burst of scene edits spent the same budget, so the two
# starved each other without either of them being what the budget was for. These
# three columns are the sub-limits that separate them — the photo pipeline's CPU
# cost, the privileged membership grants, and the append-only discussion replies.
#
# Schema-only, so the defaults are written as literals rather than read from
# `Universe::MUTATION_GROUP_LIMITS`: a migration that names an application
# constant stops working the day that constant is renamed. The numbers are 10, 10
# and 30, and the hash in the model is where they live at runtime.
#
# Nullable for the same reason `mutation_limit` is: every row gets its default, so
# a universe is protected from the moment it exists, and `NULL` is the one value an
# admin can store to mean "no limit on this group at all" — which is a different
# setting from a number and would otherwise have nowhere to go.
class AddMutationGroupLimitsToUniverses < ActiveRecord::Migration[8.1]
  def change
    add_column :universes, :photo_mutation_limit, :integer, default: 10, null: true
    add_column :universes, :membership_mutation_limit, :integer, default: 10, null: true
    add_column :universes, :discussion_mutation_limit, :integer, default: 30, null: true
  end
end
