module UniverseAuthorization
  extend ActiveSupport::Concern

  private

    def authorize_universe_access
      return if Current.universe.nil?

      # Check read access first so a private non-member cannot use a write URL
      # to distinguish a hidden universe from a forbidden collaborator action.
      begin
        authorize! :read, Current.universe
      rescue CanCan::AccessDenied
        if Current.user.nil?
          request_authentication
          return
        elsif Current.universe.private?
          raise ActiveRecord::RecordNotFound, "Universe not found"
        else
          raise
        end
      end

      begin
        authorize! universe_access_for_request, Current.universe
      rescue CanCan::AccessDenied
        if Current.user.nil?
          request_authentication
        else
          raise
        end
      end
    end

    def universe_access_for_request
      return :admin if controller_name == "universes" && %w[edit update destroy].include?(action_name)
      return :admin if controller_name == "memberships"
      return :read if %w[index show].include?(action_name)

      :write
    end
end
