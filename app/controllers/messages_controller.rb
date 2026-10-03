# The reply half of a discussion thread.
#
# Its own controller because a thread is append-only: nothing edits or deletes a
# message, so there is exactly one action here and no `show` whose read-only rule
# could be argued about. It has no `allow_unauthenticated_access`, so a guest
# pressing Reply is sent to sign in before anything is written.
class MessagesController < ApplicationController
  before_action :set_discussion

  # POST /u/:universe_slug/discussions/:discussion_id/messages
  def create
    authorize! :write, @record

    @message = @discussion.messages.new(message_params.merge(user: Current.user))

    if @message.save
      redirect_to universe_discussion_path(id: @discussion), status: :see_other,
        notice: t("discussions.flash.message_created")
    else
      # The refusal re-renders the thread with the reason beside the composer
      # rather than redirecting, because a redirect would discard what was typed —
      # which is the same rule every other form in the application follows.
      #
      # `reload` matters here: building the message added it to the association's
      # in-memory target, so the thread would render the unsaved record as though
      # it were one of its own messages, with no timestamp and no author.
      @messages = @discussion.messages.reload
      render "discussions/show", status: :unprocessable_content
    end
  end

  private

    def set_discussion
      @discussion = Current.universe.discussions.find(params.expect(:discussion_id))
      @record = RecordTarget.find!(record_type: @discussion.record_type, record_id: @discussion.record_id,
        within: Current.universe)
    end

    def message_params
      params.expect(discussion_message: [ :body ])
    end
end
