# The printable manuscript for one Story.
#
# It is a separate controller from `StoryExportsController` so its action is a
# `show`: the shared universe authorization grants `:read` to a `show` on a
# public universe, which is exactly the access the Story page itself has.
#
# The document is rendered in the manuscript layout rather than the workspace
# shell, so printing it produces the manuscript and nothing else.
class StoryManuscriptsController < ApplicationController
  allow_unauthenticated_access only: %i[ show ]

  before_action :set_story

  # GET /u/:universe_slug/s/:story_id/export/manuscript
  def show
    @manuscript = Manuscript.for(@story, scope: params[:scope])
    render layout: "manuscript"
  end
end
