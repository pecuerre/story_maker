class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :set_story

  def set_story
    where = "#{params[:controller]}/#{params[:action]}"
    return if where == "stories/index"
    return if where == "stories/new"
    return unless params[:story_id].present?

    if params[:story_id].to_i > 0
      @story = Story.find(params[:story_id])
    else
      @story = Story.find_by(slug: params[:story_id])
    end
  end
end
