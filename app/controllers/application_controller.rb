class ApplicationController < ActionController::Base
  include Authentication
  include UniverseAuthorization
  helper ModalFields

  allow_browser versions: :modern
  stale_when_importmap_changes

  # Load the session (if any) on public pages too, so Current.user is available
  # in views for things like the universes navbar dropdown.
  before_action :resume_session

  # The request immediately following a successful sign-in is the page the
  # visitor asked to return to. Consuming the marker here, before any action
  # runs, keeps the refusal fallback below scoped to that single request.
  before_action :consume_post_sign_in_destination

  before_action :set_current_universe
  # Authorization must run after the universe is resolved, but before story
  # selection or any controller loads scoped content.
  before_action :authorize_universe_access

  before_action :set_current_story

  rescue_from CanCan::AccessDenied do
    refuse_request(:forbidden)
  end
  rescue_from ActiveRecord::RecordNotFound do
    refuse_request(:not_found)
  end

  # A JSON mutation that arrives without a valid CSRF token is a refusal, not a
  # validation failure, and the shared modal contract already explains a `403` as
  # "reload the page and sign in again" — the right advice for a stale token.
  # Without this, the request would render the generic `422` exception page and the
  # editor would report that the server "did not explain why". HTML requests keep
  # Rails' own handling, because a browser form carries its token in the body.
  rescue_from ActionController::InvalidAuthenticityToken do |exception|
    raise exception unless request.format.json?

    head :forbidden
  end

  protected

  # A refusal is normally a bare status code, which is what the documented
  # 403/404 contract depends on. The one exception is the page a visitor asked to
  # return to right after signing in: a bare 403/404 there answers "nothing
  # happened" to a sign-in that actually succeeded, so that single request is sent
  # to the universe list with an explanation instead. A signed-in member following
  # an ordinary link still gets the documented status code.
  def refuse_request(status)
    return head status unless post_sign_in_destination?
    return head status unless request.format.html? && request.get?

    redirect_to root_path, alert: "That page is not available to this account. Here are the universes you can open."
  end

  def post_sign_in_destination?
    @post_sign_in_destination == true
  end

  def consume_post_sign_in_destination
    @post_sign_in_destination = session.delete(:post_sign_in_destination).present?
  end

  def current_ability
    @current_ability ||= Ability.new(Current.user)
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
