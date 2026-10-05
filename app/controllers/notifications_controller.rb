# One person's notifications: the page behind the navbar's bell, and the two writes
# that answer a bell.
#
# **It is not universe-scoped, and neither are the routes.** A notification carries the
# slug and name of the universe it is about in its own payload, which is what lets the
# navbar show a reader something from a universe they are not standing in — the person
# who submitted a draft and the reviewer who answered it are usually not looking at the
# same page. A bell scoped to the current universe could only ever answer for one of a
# reader's universes, and the question it answers is not about a universe.
#
# **Every action needs an account, and a notification has exactly one reader.** There is
# no guest version of this page and no universe authorization to ask: `Notification` is
# not in `Ability::CONTENT_CLASS_NAMES` for the same reason `Draft` and `ReviewRequest`
# are not — somebody's unfinished work under somebody else's decision is not something
# a universe publishes, and the content rules would answer `read` for a guest in a
# public universe. A notification is one person's record of what was said to them, so
# the scope is the query rather than a rule, and the query is
# `Current.user.notifications`: another person's row and a row that does not exist are
# one answer.
#
# **Marking read is explicit rather than inferred from having opened the bell.** Two
# controls, and each is asked on the page rather than in the dropdown: a reader who has
# read three of five entries has not read the other two, and marking a row read because
# a dropdown was rendered would answer that on the reader's behalf. The navbar is a
# glance — see `layouts/_notifications`.
class NotificationsController < ApplicationController
  before_action :require_authentication

  # GET /notifications
  #
  # Every notification this reader has, newest first, whatever universe it is about.
  # There is no paging: a row is one sentence, the table is one person's history of
  # things being said to them, and a second page would be a page of the same shape
  # holding less of it.
  def index
    @notifications = notifications.newest_first
  end

  # POST /notifications/:id/read
  #
  # One row, from its own line on the page. `mark_read!` is a no-op for a row that is
  # already read rather than a refusal, because pressing a control for something that
  # is already true is not a mistake worth answering — and the page it redirects back to
  # is the one the reader was on, which is the list they pressed it in.
  def read
    notifications.find(params.expect(:id)).mark_read!

    redirect_back_or_to notifications_path, status: :see_other
  end

  # POST /notifications/read_all
  #
  # Everything unread, in one write. It goes back to the page rather than to where the
  # reader pressed it, because a reader who has marked the rest by hand has already
  # left this page and the one they pressed from may no longer say what is unread.
  #
  # `update_all` rather than a loop of `save!`, because nothing here validates — a kind
  # is validated when the row is written and the column is a boolean — and this is the
  # one place where the number of writes should not grow with the number of rows.
  def read_all
    notifications.unread.update_all(read: true)

    redirect_to notifications_path, status: :see_other
  end

  private
    # This reader's own notifications. The scope is the whole of the authorization: a
    # notification is addressed to one person, so a row that is not this reader's is a
    # row that does not exist as far as this page is concerned.
    def notifications
      Current.user.notifications
    end
end
