class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :set_current_story

  private

  def set_current_story
    Current.story = Story.find_by!(slug: params[:story_slug])
  end
end
