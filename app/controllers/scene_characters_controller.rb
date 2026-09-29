# Explicit Character presence in a Scene: the Characters tab.
#
# The tab shows the union of the two participation sources the domain model
# allows — the stored presence links and the Characters who speak in a Dialogue
# Element — and labels the difference, because a speaker is a participant of the
# Scene without ever becoming a second stored row.
class SceneCharactersController < ApplicationController
  include RequiresJsonMutationFormat

  allow_unauthenticated_access only: %i[ index ]

  before_action :set_story
  before_action :set_scene
  before_action :set_scene_character, only: %i[ update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  # GET /u/:universe_slug/s/:story_id/scenes/:scene_id/characters
  #
  # A read action, so guests and read-only members see the same page. The
  # derived speakers arrive with their Elements already preloaded, and the
  # add/edit/remove controls act only on the explicit links.
  def index
    @scene_tab = "characters"
    @participants = SceneParticipants.for(@scene)
    @linked_character_ids = @participants.explicit_links.map(&:character_id)
    # Every universe Character is offered. A Character already in the scene is not
    # hidden from the picker, because a stale page or a second window can submit
    # one anyway; the model reports that as an ordinary validation error, which
    # the editor renders in the modal.
    @character_options = universe_characters
  end

  # POST /u/:universe_slug/s/:story_id/scenes/:scene_id/characters
  #
  # The Character is resolved through the current Universe, so another universe's
  # id is a 404 rather than a cross-scope write. The model's own same-Universe
  # rule then covers every other caller, including direct model use.
  def create
    attributes = scene_character_params
    raise ActionController::ParameterMissing, :character_id unless attributes[:character_id].present?

    link = @scene.scene_characters.new(character: Current.universe.characters.find(attributes[:character_id]),
      role: attributes[:role])

    respond_to do |format|
      if link.save
        format.json { render json: scene_character_json(link), status: :created }
      else
        format.json { render json: link.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH /u/:universe_slug/s/:story_id/scenes/:scene_id/characters/:id
  #
  # Both the Character and the role are editable, because the editor offers both
  # controls and a control that looks editable but is ignored would be worse than
  # no control at all. Repointing a link at a Character that is already in the
  # scene is the model's duplicate error rather than a second row.
  def update
    @scene_character.assign_attributes(editable_scene_character_attributes)

    respond_to do |format|
      if @scene_character.save
        format.json { render json: scene_character_json(@scene_character), status: :ok }
      else
        format.json { render json: @scene_character.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /u/:universe_slug/s/:story_id/scenes/:scene_id/characters/:id
  #
  # Removing a presence link never removes a Character and never changes who
  # speaks in an Element: those are separate links with separate consequences.
  def destroy
    @scene_character.soft_delete

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  private

  def set_story
    @story = Current.universe.stories.find(params.expect(:story_id))
  end

  def set_scene
    @scene = @story.scenes.find(params.expect(:scene_id))
  end

  # Loaded through the Scene association, so a link from another Scene, Story,
  # or Universe is a 404 rather than a cross-scope write.
  def set_scene_character
    @scene_character = @scene.scene_characters.find(params.expect(:id))
  end

  # One ordered list backs the picker, and it matches the order the Characters
  # workspace uses so a Character is recognizable by its name alone.
  def universe_characters
    @universe_characters ||= Current.universe.characters.reorder(:name, :id).to_a
  end

  def scene_character_params
    params.expect(scene_character: [ :character_id, :role ])
  end

  # An update may carry either field on its own, so a role-only edit never clears
  # the link and a character-only edit never clears the role. A blank Character
  # means "keep the current one". A payload with neither field is malformed
  # rather than a no-op that would look like a successful save.
  def editable_scene_character_attributes
    attributes = scene_character_params
    resolved = {}
    resolved[:role] = attributes[:role] if attributes.key?(:role)

    character_id = attributes[:character_id]
    resolved[:character] = Current.universe.characters.find(character_id) if character_id.present?

    raise ActionController::BadRequest, "a scene character update must change the character or the role" if resolved.empty?

    resolved
  end

  def scene_character_json(link)
    {
      id: link.id,
      character_id: link.character_id,
      role: link.role,
      url: universe_story_scene_scene_character_path(story_id: @story, scene_id: @scene, id: link)
    }
  end
end
