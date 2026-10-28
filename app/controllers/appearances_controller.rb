# The Story-wide appearance grid. It is a read of the Story, so it is
# guest-readable like the Story page itself and the Scene list.
#
# There is no mutation action and no stored result: `AppearanceGrid` answers the
# grid from the Story's live Scenes, the union of explicit presence links and
# Dialogue speakers, and the prose mention index. A name written in an Element
# never becomes a presence link here.
class AppearancesController < ApplicationController
  allow_unauthenticated_access only: %i[ show ]

  before_action :set_story

  def show
    @grid = AppearanceGrid.new(@story)
  end
end
