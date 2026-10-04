# One draft's author's request that somebody else look at it before it is applied.
#
# This is the stored half of Phase 5's review workflow: `github` mode does not
# apply a draft, it hands the draft to a reviewer, and this row is the handoff.
#
# **A new row per submission rather than columns on `drafts`.** A draft that is
# rejected comes back as a working draft and may be submitted again, so "which
# review is this draft waiting for" is not one fact about the draft — it is a
# history of submissions, and only the last one is live. A remembered change is
# also append-only for the same reason a change is (ADR 0019): what was asked for
# is a statement about one moment.
#
# `universe_id` and `submitted_by_id` are both derivable from the draft — the
# universe the draft was authorized in, and its one author — and both are stored
# anyway. They are what the reviewer's list is queried by without a join, and a
# derivable column that is also stored is the case where two columns can
# disagree; `ReviewRequest` validates both against the draft rather than trusting
# either, which is `DraftChangeOutcome`'s arrangement and `Discussion`'s.
#
# `reviewed_by_id` is nullable because a request nobody has looked at yet has no
# reviewer, and `review_notes` is nullable because an approval has nothing to
# explain. A **rejection** is different: its whole purpose is to tell the author
# why, so the model refuses a rejected row with no notes — the same reasoning
# `Draft`'s `closed_at` validation gives, where the moment a closure happened
# cannot be read off `updated_at` after the fact.
#
# The partial unique index is the rule "one draft has one review in flight". It is
# partial for the same reason the open-draft index is: a rejected submission stays
# behind as history and the author may submit again, while two *pending* requests
# for one draft would mean two reviewers racing to apply the same changes. The
# status list is frozen in SQL because a migration has to keep saying what it said
# on the day it ran, and `test/models/review_request_test.rb` holds the two lists
# together.
class CreateReviewRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :review_requests do |t|
      t.references :draft, null: false, foreign_key: true
      t.references :universe, null: false, foreign_key: true
      t.references :submitted_by, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "pending"
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.text :review_notes

      t.timestamps
    end

    add_index :review_requests, :draft_id,
      unique: true,
      where: "status = 'pending'",
      name: "index_review_requests_on_draft_while_pending"
  end
end
