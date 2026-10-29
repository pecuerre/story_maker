# One completed story-interchange import, kept so its page can list what it reported.
#
# The run's answer is too large for a flash: a source with a few hundred reported
# source items produces a message bigger than the 4 KB a session cookie may hold, and
# `ActionDispatch::Cookies::CookieOverflow` is raised while the response commits —
# after the import transaction has already succeeded, which turned a completed import
# into a 500. The row is therefore written inside that transaction and read by the
# page the write redirects to.
#
# **The universe is copied in, not referenced.** A later run replaces the universe
# this one created, and a soft-deleted universe is hidden from the ordinary scope, so
# a run that resolved its universe to print itself would lose the name it has to say.
# `universe_name` and `universe_slug` are the names as this run wrote them; the page
# links to a live universe only when one still has that slug. This is the trade
# `notifications.payload` makes (ADR 0025): a stored sentence outlives its subject.
#
# `outcomes` is the array of per-slice answers the preview and the task already
# compute — `label_key`, `created`, and `skipped`. It is JSON rather than a child
# table because nothing queries it and the page renders it whole.
#
# `created_at` with **no `updated_at`**: the row is never edited. `user_id` is the
# operator who ran it, with a foreign key, because a run that named no account would
# not be a report of who did it.
class CreateStoryInterchangeRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :story_interchange_runs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :source, null: false
      t.string :universe_name, null: false
      t.string :universe_slug, null: false
      t.boolean :replaced, null: false, default: false
      t.json :outcomes, null: false

      t.datetime :created_at, null: false
    end
  end
end
