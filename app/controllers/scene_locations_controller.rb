# Explicit Location presence in a Scene: the Locations tab.
#
# The tab is plural because a Scene may use any number of Locations, and each
# linked one may carry the author's own free-text role. Every row is a stored
# presence link: nothing is derived from a Location, so there is no second
# participation source to reconcile here the way the Characters tab has.
class SceneLocationsController < ApplicationController
  allow_unauthenticated_access only: %i[ index ]
  include RequiresJsonMutationFormat

  before_action :set_story
  before_action :set_scene
  before_action :set_scene_location, only: %i[ update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  # GET /u/:universe_slug/s/:story_id/scenes/:scene_id/locations
  #
  # A read action, so guests and read-only members see the same page. Locations
  # are hierarchical, so the whole universe list is loaded once and every linked
  # place is shown with its ancestor path rather than a flat, ambiguous name.
  def index
    @scene_tab = "locations"
    # Ordered by the linked Location's name, so the tab reads as a list of places
    # rather than of link rows. The tree order the picker uses is deliberately not
    # reused here: a flat list is easier to scan, and the ancestor path in each row
    # is what disambiguates two places with the same name.
    @scene_locations = @scene.scene_locations.includes(:location)
      .sort_by { |link| [ link.location.name.to_s.downcase, link.id ] }
    @location_options = Current.universe.locations.reorder(:position, :id).to_a
    @location_paths = LocationPaths.build(@location_options)
    # Every universe Location is offered. A Location already in the scene is not
    # hidden from the picker, because a stale page or a second window can submit
    # one anyway; the model reports that as an ordinary validation error, which
    # the editor renders in the modal.
  end

  # POST /u/:universe_slug/s/:story_id/scenes/:scene_id/locations
  #
  # The Location is resolved through the current Universe, so another universe's
  # id is a 404 rather than a cross-scope write. The model's own same-Universe
  # rule then covers every other caller, including direct model use.
  def create
    attributes = scene_location_params
    raise ActionController::ParameterMissing, :location_id unless attributes[:location_id].present?

    link = @scene.scene_locations.new(location: Current.universe.locations.find(attributes[:location_id]),
      role: attributes[:role])

    respond_to do |format|
      if link.save
        format.json { render json: scene_location_json(link), status: :created }
      else
        format.json { render json: link.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH /u/:universe_slug/s/:story_id/scenes/:scene_id/locations/:id
  #
  # Both the Location and the role are editable, because the editor offers both
  # controls and a control that looks editable but is ignored would be worse than
  # no control at all. Repointing a link at a Location that is already in the
  # scene is the model's duplicate error rather than a second row.
  def update
    @scene_location.assign_attributes(editable_scene_location_attributes)

    respond_to do |format|
      if @scene_location.save
        format.json { render json: scene_location_json(@scene_location), status: :ok }
      else
        format.json { render json: @scene_location.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /u/:universe_slug/s/:story_id/scenes/:scene_id/locations/:id
  #
  # Removing a presence link never removes a Location, and never removes a nested
  # place: a Location belongs to the Universe and is shared by every Story, so
  # this only withdraws one Scene's claim on it.
  def destroy
    @scene_location.soft_delete

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
    def set_scene_location
      @scene_location = @scene.scene_locations.find(params.expect(:id))
    end

    def scene_location_params
      params.expect(scene_location: [ :location_id, :role ])
    end

    # An update may carry either field on its own, so a role-only edit never clears
    # the link and a location-only edit never clears the role. A blank Location
    # means "keep the current one". A payload with neither field is malformed
    # rather than a no-op that would look like a successful save.
    def editable_scene_location_attributes
      attributes = scene_location_params
      resolved = {}
      resolved[:role] = attributes[:role] if attributes.key?(:role)

      location_id = attributes[:location_id]
      resolved[:location] = Current.universe.locations.find(location_id) if location_id.present?

      raise ActionController::BadRequest, "a scene location update must change the location or the role" if resolved.empty?

      resolved
    end

    def scene_location_json(link)
      {
        id: link.id,
        location_id: link.location_id,
        role: link.role,
        url: universe_story_scene_scene_location_path(story_id: @story, scene_id: @scene, id: link)
      }
    end
end
