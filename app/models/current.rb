class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :universe
  delegate :user, to: :session, allow_nil: true
end
