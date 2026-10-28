# The Story-wide Scene matrix. It is a read of the Story, so it is guest-readable
# like the Story page, the Scene list, and the Appearance grid.
#
# There is no mutation action and no stored result: `SceneMatrix` answers every
# row from the Story's live Scenes and the records already stored on them. The
# page never reorders a Scene and never becomes a second editor — a row links to
# Scene Details, where the ordinary draft-backed form does the writing.
class SceneMatricesController < ApplicationController
  allow_unauthenticated_access only: %i[ show ]

  before_action :set_story
  # The Section path shown in a row is built once for the whole Story, exactly
  # as the Scenes list builds it, so no row walks ancestors of its own.
  before_action :set_section_paths

  def show
    @matrix = SceneMatrix.new(@story)
  end

  private
    def set_section_paths
      @section_paths = SectionPaths.build(@story.sections.reorder(:position, :id).to_a)
    end
end
