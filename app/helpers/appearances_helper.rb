module AppearancesHelper
  # The body of a Scene column's popover, one fact per line: every Section level
  # from the root, then the Scene. The popover carries no title, so these lines
  # are the whole of it. An ungrouped Scene still gets a line, because a missing
  # Section is a fact to state rather than an empty row.
  def appearance_scene_popover_body(scene, section_paths)
    path = section_paths.path_for(scene.section_id) || [ section_paths.ungrouped_label ]

    (path + [ t("appearances.scene_popover_scene",
      position: scene.position + 1, name: scene.name) ]).join("\n")
  end
end
