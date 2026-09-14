class ApplicationController < ActionController::Base
  include Authentication
  helper ModalFields

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :set_current_universe

  protected

  def default_url_options
    return super unless Current.universe

    super.merge()
  end

  def set_current_universe
    return unless params[:universe_slug].present?

    Current.universe = Universe.find_by!(slug: params[:universe_slug])
  end
end
