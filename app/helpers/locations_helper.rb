module LocationsHelper
  # The reason(s) one participant is at a Location, read from the same two
  # sources `SceneParticipants` unions. A stored link may carry the author's own
  # free-text role; speaking is derived and is stated as such, because it has no
  # stored role to show. A linked person with no role says so rather than
  # rendering an empty reason.
  def location_presence_reason(participant)
    reasons = []
    reasons << participant.role if participant.role.present?
    reasons << t("locations.presence.reason.speaks") if participant.speaks?
    reasons << t("locations.presence.reason.no_role") if reasons.empty?

    reasons.to_sentence
  end
end
