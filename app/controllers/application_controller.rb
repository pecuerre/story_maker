class ApplicationController < ActionController::Base
  include Authentication
  helper ModalFields

  allow_browser versions: :modern
  stale_when_importmap_changes

  # Load the session (if any) on public pages too, so Current.user is available
  # in views for things like the universes navbar dropdown.
  before_action :resume_session
  before_action :set_current_universe
  before_action :set_current_story

  protected

  def default_url_options
    return super unless Current.universe

    super.merge()
  end

  def set_current_universe
    return unless params[:universe_slug].present?

    Current.universe = Universe.find_by!(slug: params[:universe_slug])
  end

  # Resolve the story the sidebar and story-scoped pages should point at.
  # An explicit story (params[:story_id] or the stories resource) wins and is
  # remembered in the session; otherwise fall back to the remembered story.
  # There is deliberately no fallback to the universe's first story: a story is
  # only "current" when the user picked it (the WHAT/HOW sidebar cards and the
  # top bar story menu stay hidden until then).
  def set_current_story
    Current.story = nil
    return if Current.universe.nil?

    stories = Current.universe.stories.order(:id)
    story_id = params[:story_id].presence || (controller_name == "stories" ? params[:id] : nil)

    if story_id.present?
      story = stories.find(story_id)
      session[:current_story_ids] = remembered_story_ids.merge(Current.universe.id.to_s => story.id)
      Current.story = story
    else
      Current.story = stories.find_by(id: remembered_story_ids[Current.universe.id.to_s])
    end
  end

  def remembered_story_ids
    session[:current_story_ids] || {}
  end
end
