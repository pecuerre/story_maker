# A conversation about one record.
#
# This is the fourth page shape rather than another reading of `show`. The thread
# is append-only and guest-readable, so a reader and a read-only member see exactly
# the same messages; only the composer differs, and it is rendered for whoever may
# write. What stays absolute is that a `GET` never writes: the "Discuss" control on
# a record's details page POSTs to `create`, which finds or creates the thread and
# redirects to it, so a thread is never created as a side effect of opening a page.
class DiscussionsController < ApplicationController
  allow_unauthenticated_access only: :show

  before_action :set_discussion, only: :show

  # GET /u/:universe_slug/discussions/:id
  def show
    @message = DiscussionMessage.new
    @messages = @discussion.messages
  end

  # POST /u/:universe_slug/discussions
  #
  # Find or create, not create: the control is idempotent, so pressing it on a
  # record that already has a thread lands on that thread instead of failing.
  def create
    record = find_record
    authorize! :write, record

    discussion = record.find_or_create_discussion

    redirect_to universe_discussion_path(id: discussion), status: :see_other
  end

  private

    # Both the thread and its record are read through the universe the request has
    # already authorized. The thread through its own `universe_id` foreign key, the
    # record through `RecordTarget`, so a stored `record_type` outside the content
    # registry, an unknown id, a soft-deleted record, and a record in another
    # universe are one indistinguishable 404 rather than a page that cannot render.
    def set_discussion
      @discussion = Current.universe.discussions.find(params.expect(:id))
      @record = RecordTarget.find!(record_type: @discussion.record_type, record_id: @discussion.record_id,
        within: Current.universe)
    end

    def find_record
      reference = params.expect(discussion: [ :record_type, :record_id ])

      RecordTarget.find!(record_type: reference[:record_type], record_id: reference[:record_id],
        within: Current.universe)
    end
end
