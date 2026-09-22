class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :universe
  attribute :story
  delegate :user, to: :session, allow_nil: true
end
