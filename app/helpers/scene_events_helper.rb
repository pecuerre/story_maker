module SceneEventsHelper
  # The values the shared modal fills when a row's Edit control opens it. One key
  # per editable control, named exactly as the submitted parameter, so the modal's
  # generic value loop can place them without knowing this workspace.
  def scene_event_fields_json(link)
    { event_id: link.event_id, role: link.role }.to_json
  end
end
