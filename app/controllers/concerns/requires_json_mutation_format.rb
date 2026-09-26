# A JSON-only mutation controller refuses a request that does not ask for JSON
# before it can write anything. Without this guard, `respond_to` raises
# ActionController::UnknownFormat *after* the record has already been saved: the
# write commits, the caller is answered 406, and a retry creates a duplicate.
#
# The guard is opt-in per action through an explicit `before_action` rather than
# a blanket filter, so each controller keeps its documented callback order.
module RequiresJsonMutationFormat
  extend ActiveSupport::Concern

  private
    def require_json_mutation_format
      head :not_acceptable unless request.format.json?
    end
end
