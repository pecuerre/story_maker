# One thing that happened to one person, kept so they can be told about it.
#
# This is the stored half of slice 5.5's in-app notifications. Nothing about a
# collaboration event reaches anybody in this application today except by their own
# action: a submitted draft appears in a reviewer's queue, an approval redirects the
# reviewer to what it wrote, and a rejection is a page the author has to go and look
# at. Every one of those answers the question "what just happened" for the person who
# just did it and leaves the other person waiting, which is the wrong way round for a
# workflow whose whole point is that somebody else decides.
#
# **The column is `kind`, not `type`.** `type` is the column the collaboration plan
# named, and it cannot be used: Rails reads `type` as the single-table-inheritance
# discriminator, so `Notification.create(kind: ...)` spelled `type` would try to
# constantize `"review_submitted"` as a class and raise `SubclassNotFound` on a value
# this application invented. Disabling that with `inheritance_column` would work and
# would be a second thing to remember about this table, so the column is named for
# what it says, the same answer ADR 0019 gave for `draft_changes.payload`.
#
# **The payload is a frozen sentence rather than a pointer.** It holds the universe's
# slug and name, the draft and submission ids, the other person's name, and a
# reviewer's note where there is one. A notification therefore renders without
# resolving anything, which is what lets it survive what it is about: the submission
# it names is destroyed with its draft and its universe, and a bell entry that raised
# a 404 on a universe somebody renamed would be worse than no bell. The trade is
# deliberate duplication of names, validated by nothing, because the alternative is a
# row that can only be rendered while every subject of it still exists.
#
# `user_id` rather than an owner-and-type pair because one person is the only reader
# of a notification: this is a statement about somebody's work, and there is no
# version of it for somebody else. A foreign key with a cascade, because a
# notification cannot outlive the account it was written to.
#
# `created_at` with **no `updated_at`**: the row is never edited. `read` is the one
# column that changes after it is written, and nothing reports when it changed, so an
# `updated_at` would be a column with no reader.
#
# The two indexes answer the only two questions the surfaces ask. The reader's list is
# newest first over their own rows, so `[user_id, created_at, id]` serves it and
# breaks a tie the way `draft_changes` does. `[user_id, read]` is the navbar's
# **unread** count, which is asked on every page of the application and is therefore
# the one query this table has to keep cheap.
class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.boolean :read, null: false, default: false
      t.json :payload

      t.datetime :created_at, null: false
    end

    add_index :notifications, [ :user_id, :created_at, :id ]
    add_index :notifications, [ :user_id, :read ]
  end
end
