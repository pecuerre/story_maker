module StoryWorkspaceHelper
  # The Scene workspace's destinations. One helper rather than the same array in
  # every view, because another destination is exactly when a copy falls behind.
  #
  # Sections, Plots, and the Story analytics pages are no longer part of this
  # strip: each is its own destination in the left sidebar. The strip carries
  # only the two ways to read the Scene sequence the Story already owns.
  def story_workspace_tabs(story)
    [
      { label: t("sidebar.scenes"), path: universe_story_scenes_path(story_id: story), controller: :scenes },
      { label: t("sidebar.scene_board"), path: universe_story_scene_board_path(story_id: story), controller: :scene_boards }
    ]
  end
end
