module LocationsHelper
  # The shared tree editor is narrow by default, which suits a tag's few fields.
  # A Location's editor is the wide, scrollable dialog the flat-list record
  # editors use, because it carries a short summary and a Markdown description
  # beside its name, parent, tags, and photo. Both the tree and the details
  # page's Edit control read it here, so the one editor cannot open at two
  # different widths.
  def location_editor_dialog_class
    "modal-dialog modal-lg modal-dialog-scrollable"
  end

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
