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
        raise ActiveRecord::RecordNotFound, "Universe not found" unless Current.universe.public?

        if Current.user.nil?
          request_authentication
          return
        else
          raise
        end
      end

      begin
        authorize! universe_access_for_request, Current.universe
      rescue CanCan::AccessDenied
        if Current.user.nil?
          raise ActiveRecord::RecordNotFound, "Universe not found" unless Current.universe.public?

          request_authentication
        else
          raise
        end
      end
    end

    def universe_access_for_request
      return :admin if controller_name == "universes" && %w[edit update destroy].include?(action_name)
      return :admin if controller_name == "memberships"
      # Reading somebody else's unfinished work and deciding what happens to it is the
      # owner's and the admins' call, and it is the *whole* controller rather than two of
      # its four actions: a list of submissions is itself the answer to "what is waiting
      # here", and a queue a plain writer can read is a queue they have no business in.
      return :admin if controller_name == "review_requests"
      return :read if %w[index show].include?(action_name)

      :write
    end
end
