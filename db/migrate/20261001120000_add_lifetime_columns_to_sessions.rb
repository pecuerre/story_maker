# Session lifetime and source binding.
#
# A session row previously recorded only who it belonged to and where it came
# from, so nothing in the application could tell an abandoned session from an
# active one and a copied session cookie stayed usable until its owner signed
# out. Two columns make both questions answerable:
#
#   * `expires_at` is the absolute end of the session's life, fixed when it is
#     created and never extended. It is the ceiling that no amount of activity
#     can push back.
#   * `last_used_at` is when the session was last seen carrying a request. The
#     idle timeout is measured from it, so an idle session stops being accepted
#     even though its absolute deadline has not passed.
#
# `expires_at` is set by the application rather than defaulted in the database,
# because the lifetime is a policy value (`Session::ABSOLUTE_TIMEOUT`) and a
# column default would silently encode a second, competing copy of it.
class AddLifetimeColumnsToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :expires_at, :datetime
    add_column :sessions, :last_used_at, :datetime

    # The cleanup task and the expiry check both ask "which sessions are past
    # their deadline", so that question gets an index rather than a full scan.
    add_index :sessions, :expires_at
  end
end
