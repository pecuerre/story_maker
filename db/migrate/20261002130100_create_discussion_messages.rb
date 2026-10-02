# The messages of one conversation.
#
# `body` is a plain text column: the collaboration plan deliberately defers
# markdown in discussions, so storing formatted prose would be storing a decision
# this slice has not made. `discussion_id` is a real foreign key — unlike the
# polymorphic reference on the thread itself, this side always names one table —
# so a message can never outlive the thread it belongs to.
#
# The composite index matches the one query a thread makes: its messages in the
# order they were written. Ordering on `created_at` alone is not stable for two
# messages written inside the same clock tick, so `id` is the tiebreaker, the
# same `(position, id)` shape the ordered content sequences use.
class CreateDiscussionMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :discussion_messages do |t|
      t.references :discussion, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false

      t.timestamps
    end

    add_index :discussion_messages, [ :discussion_id, :created_at, :id ]
  end
end
