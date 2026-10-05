# What an author said when they handed a draft over.
#
# `review_notes` is the reviewer's sentence **to** the author. This is the author's
# own sentence **with** the submission: "this is the second attempt", "I only
# touched these two scenes", "the rename is deliberate". Without it the reviewer
# reads a list of raw `base_version` diffs with no idea which ones were intended,
# and the author has no way to say which they were.
#
# It is nullable because most submissions need no explanation, the same argument
# `review_notes` makes for an approval. It is **not** required the way a
# rejection's notes are: those exist to tell the author why their work was refused,
# and a refusal with no reason is a decision the author can only discover happened.
# A submission is a request, and a request with nothing to add is still a request.
#
# One column rather than a message thread, because slice 5.3 is deliberately a
# single handover and slice 5.5 adds in-app notifications; a discussion under a
# submission is a later question, not this one. The column is on `review_requests`
# rather than on `drafts` for the reason that table exists at all: a rejected draft
# comes back as working work and may be submitted again with a different message,
# so what was asked for is a statement about one submission, not about the draft.
#
# A migration is schema-only and keeps saying what it said on the day it ran: it
# adds the column and does not backfill, because every existing row was submitted
# before this column existed and a message nobody wrote must not be invented.
class AddSubmissionMessageToReviewRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :review_requests, :submission_message, :text
  end
end
