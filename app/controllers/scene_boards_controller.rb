# The Story-wide Scene planning board. It is a read of the Story, so it is
# guest-readable like the Scene list, the Scene matrix, and the Appearance grid.
#
# There is no mutation action and no stored result of its own: `SceneBoard`
# answers every column from the Story's live Sections and Scenes. A card posts
# the ordinary `ScenesController#move` and `#group` actions, so the board never
# becomes a second editor with its own order or validation; Scene Details keeps
# the draft-backed form that does the field writing.
class SceneBoardsController < ApplicationController
  allow_unauthenticated_access only: %i[ show ]

  before_action :set_story

  def show
    @board = SceneBoard.new(@story)
  end
end
