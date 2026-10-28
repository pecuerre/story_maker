# The Story-wide Scene planning board. It is a read of the Story, so it is
# guest-readable like the Scene list, the Scene matrix, and the Appearance grid.
#
# There is no mutation action and no stored result: `SceneBoard` answers every
# column from the Story's live Sections and Scenes. The board never reorders a
# Scene and never becomes a second editor — a card links to Scene Details, where
# the ordinary draft-backed form does the writing.
class SceneBoardsController < ApplicationController
  allow_unauthenticated_access only: %i[ show ]

  before_action :set_story

  def show
    @board = SceneBoard.new(@story)
  end
end
