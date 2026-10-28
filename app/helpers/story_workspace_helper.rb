module StoryWorkspaceHelper
  # The Story workspace's destinations. One helper rather than the same array in
  # five views, because another destination is exactly when a copy falls behind.
  #
  # **Narrative order is the one signed-in destination.** The other destinations
  # are guest-readable on a public universe, but the comparison is not, so a
  # guest is not offered a link that would only send them to sign in. The
  # controller still enforces the rule; this only keeps the strip honest.
  def story_workspace_tabs(story)
    tabs = [
      { label: t("sidebar.sections"), path: universe_story_sections_path(story_id: story), controller: :sections },
      { label: t("sidebar.plots"), path: universe_story_plots_path(story_id: story), controller: :plots },
      { label: t("sidebar.scenes"), path: universe_story_scenes_path(story_id: story), controller: :scenes },
      { label: t("sidebar.scene_board"), path: universe_story_scene_board_path(story_id: story), controller: :scene_boards },
      { label: t("sidebar.scene_matrix"), path: universe_story_scene_matrix_path(story_id: story), controller: :scene_matrices },
      { label: t("sidebar.appearances"), path: universe_story_appearances_path(story_id: story), controller: :appearances }
    ]

    if Current.user.present?
      tabs << {
        label: t("sidebar.narrative_order"),
        path: universe_story_narrative_order_path(story_id: story),
        controller: :narrative_orders
      }
    end

    tabs
  end
end
