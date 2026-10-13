# The one flag that is not about a universe: may this account configure the
# platform itself?
#
# Every other privilege in this application is a level *inside* a universe, read
# from a membership row or from the owner column. The per-universe mutation budget
# followed that rule, and the universe-creation limit could not: it is read before
# there is a universe to own the setting, so it belongs to the platform and needed
# somebody who could change it.
#
# `false` on every existing row, deliberately and `NOT NULL`: a new column that
# defaulted to `true` would hand the privilege to every account the day it was
# added. Nothing in the interface sets it — it is an operator flag, assigned in a
# console, a seed, or a fixture — and `Ability` is the only thing that reads it.
class AddPlatformAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :platform_admin, :boolean, default: false, null: false
  end
end
