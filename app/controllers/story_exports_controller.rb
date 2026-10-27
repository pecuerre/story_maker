# The Story export surface's entry page: the formats it offers and the scope
# choice for the one it has.
#
# It is a read of the Story, so it is guest-readable like `StoriesController` and
# resolves the Story through the request's Universe. Choosing a scope is a GET
# parameter on the manuscript, so this page renders no mutation control.
class StoryExportsController < ApplicationController
  allow_unauthenticated_access only: %i[ show ]

  before_action :set_story

  # GET /u/:universe_slug/s/:story_id/export
  def show
    @scope = Manuscript.scope(params[:scope])
  end
end
