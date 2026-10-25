# Scene-level tropes: the Tropes tab.
#
# The catalogue is a code-owned reference list, so this controller never creates a
# trope. It records which references this Scene carries, with the author's own
# context note, and lets a writer add, re-annotate, or remove one. The tab lists
# only the saved assignments; the full catalogue is offered through the editor's
# picker rather than rendered as a stack of cards.
class SceneTropesController < ApplicationController
  include RequiresJsonMutationFormat
  include DraftMutation

  allow_unauthenticated_access only: %i[ index ]

  before_action :set_story
  before_action :set_scene
  before_action :set_scene_trope, only: %i[ update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  # GET /u/:universe_slug/s/:story_id/scenes/:scene_id/tropes
  #
  # A read action, so guests and read-only members see the same list. Rows are
  # ordered by the catalogue name so the tab reads as a list of references rather
  # than of assignment rows.
  def index
    @scene_tab = "tropes"
    @scene_tropes = @scene.scene_tropes.to_a
      .sort_by { |assignment| [ assignment.trope&.name.to_s.downcase, assignment.id ] }
    # Every catalogue entry is offered, in alphabetical order so a growing
    # catalogue is browsable rather than read in curation order. One already
    # assigned to this scene is not hidden, because a stale page or a second
    # window can submit one anyway; the model reports that as an ordinary
    # validation error, which the editor renders in the modal.
    @trope_options = TropeCatalog.entries.sort_by { |entry| entry.name.downcase }
  end

  # POST /u/:universe_slug/s/:story_id/scenes/:scene_id/tropes
  #
  # The catalogue slug is validated by the model, so an unknown reference is an
  # ordinary field error rather than something the controller has to guess at.
  def create
    attributes = scene_trope_params
    # The picker always submits the key, even when the author has not chosen a
    # reference: a blank choice is an ordinary field error the model reports in
    # the modal. A payload missing the key entirely is malformed instead.
    raise ActionController::ParameterMissing, :trope_slug unless attributes.key?(:trope_slug)

    assignment = @scene.scene_tropes.new(trope_slug: attributes[:trope_slug],
      context_note: attributes[:context_note])
    return if remember_draft_create(assignment, attributes)

    respond_to do |format|
      if assignment.save
        format.json { render json: scene_trope_json(assignment), status: :created }
      else
        format.json { render json: assignment.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH /u/:universe_slug/s/:story_id/scenes/:scene_id/tropes/:id
  #
  # Both the reference and the note are editable, because the editor offers both
  # controls. Repointing an assignment at a reference the Scene already carries is
  # the model's duplicate error rather than a second row.
  def update
    @scene_trope.assign_attributes(editable_scene_trope_attributes)
    # No attributes are passed: the assignment has already been changed, so what
    # the live path would have written is the record's own pending change. A blank
    # `trope_slug` means "keep the stored reference" here.
    return if remember_draft_update(@scene_trope)

    respond_to do |format|
      if @scene_trope.save
        format.json { render json: scene_trope_json(@scene_trope), status: :ok }
      else
        format.json { render json: @scene_trope.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /u/:universe_slug/s/:story_id/scenes/:scene_id/tropes/:id
  #
  # Removing an annotation removes this assignment only. The catalogue is shared
  # code, and the same reference on another Scene or on the Story is unaffected.
  def destroy
    return if remember_draft_delete(@scene_trope)

    @scene_trope.destroy

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  private

    def set_scene
      @scene = @story.scenes.find(params.expect(:scene_id))
    end

    # Loaded through the Scene association, so an assignment from another Scene,
    # Story, or Universe is a 404 rather than a cross-scope write.
    def set_scene_trope
      @scene_trope = @scene.scene_tropes.find(params.expect(:id))
    end

    def scene_trope_params
      params.expect(scene_trope: [ :trope_slug, :context_note ])
    end

    # An update may carry either field on its own, so a note-only edit never
    # clears the reference and a reference-only edit never clears the note. A
    # blank reference means "keep the stored one". A payload with neither field is
    # malformed rather than a no-op that would look like a successful save.
    def editable_scene_trope_attributes
      attributes = scene_trope_params
      resolved = {}
      resolved[:context_note] = attributes[:context_note] if attributes.key?(:context_note)

      trope_slug = attributes[:trope_slug]
      resolved[:trope_slug] = trope_slug if trope_slug.present?

      raise ActionController::BadRequest, "a scene trope update must change the trope or the context note" if resolved.empty?

      resolved
    end

    def scene_trope_json(assignment)
      {
        id: assignment.id,
        trope_slug: assignment.trope_slug,
        context_note: assignment.context_note,
        url: universe_story_scene_scene_trope_path(story_id: @story, scene_id: @scene, id: assignment)
      }
    end
end
