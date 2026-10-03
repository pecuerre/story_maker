# Explicit Item presence in a Scene: the Items tab.
#
# Unlike the Characters tab there is only one participation source here. An Item
# is a shared universe record and nothing derives from it, so every row is a
# stored presence link with a role, and the counts the page shows and the counts
# the mutations change are the same list.
class SceneItemsController < ApplicationController
  include RequiresJsonMutationFormat
  include DraftMutation

  allow_unauthenticated_access only: %i[ index ]

  before_action :set_story
  before_action :set_scene
  before_action :set_scene_item, only: %i[ update destroy ]
  before_action :require_json_mutation_format, only: %i[ create update destroy ]

  # GET /u/:universe_slug/s/:story_id/scenes/:scene_id/items
  #
  # A read action, so guests and read-only members see the same page, and the
  # linked Items arrive with their Scene already known so the rows cost no
  # further query.
  def index
    @scene_tab = "items"
    # Ordered by the linked Item's name, so the tab reads as a list of things
    # rather than of link rows, and the same Item always lands in the same place.
    @scene_items = @scene.scene_items.includes(:item).sort_by { |link| [ link.item.name.to_s.downcase, link.id ] }
    # Every universe Item is offered. An Item already in the scene is not hidden
    # from the picker, because a stale page or a second window can submit one
    # anyway; the model reports that as an ordinary validation error, which the
    # editor renders in the modal.
    @item_options = universe_items
  end

  # POST /u/:universe_slug/s/:story_id/scenes/:scene_id/items
  #
  # The Item is resolved through the current Universe, so another universe's id is
  # a 404 rather than a cross-scope write. The model's own same-Universe rule then
  # covers every other caller, including direct model use.
  def create
    attributes = scene_item_params
    raise ActionController::ParameterMissing, :item_id unless attributes[:item_id].present?

    link = @scene.scene_items.new(item: Current.universe.items.find(attributes[:item_id]),
      role: attributes[:role])
    return if remember_draft_create(link, attributes)

    respond_to do |format|
      if link.save
        format.json { render json: scene_item_json(link), status: :created }
      else
        format.json { render json: link.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH /u/:universe_slug/s/:story_id/scenes/:scene_id/items/:id
  #
  # Both the Item and the role are editable, because the editor offers both
  # controls and a control that looks editable but is ignored would be worse than
  # no control at all. Repointing a link at an Item that is already in the scene
  # is the model's duplicate error rather than a second row.
  def update
    @scene_item.assign_attributes(editable_scene_item_attributes)
    # No attributes are passed: the link has already been assigned, and what the
    # live path would have written is the record's own pending change rather than
    # the submitted payload — a blank `item_id` means "keep the stored one" here,
    # and the resolved foreign key is the value that must be remembered.
    return if remember_draft_update(@scene_item)

    respond_to do |format|
      if @scene_item.save
        format.json { render json: scene_item_json(@scene_item), status: :ok }
      else
        format.json { render json: @scene_item.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /u/:universe_slug/s/:story_id/scenes/:scene_id/items/:id
  #
  # Removing a presence link never removes an Item. An Item belongs to the
  # Universe and is shared by every Story, so this only withdraws one Scene's
  # claim on it.
  def destroy
    return if remember_draft_delete(@scene_item)

    @scene_item.soft_delete

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
    def set_scene_item
      @scene_item = @scene.scene_items.find(params.expect(:id))
    end

    # One ordered list backs the picker, and it matches the order the Items
    # workspace uses so an Item is recognizable by its name alone.
    def universe_items
      @universe_items ||= Current.universe.items.reorder(:name, :id).to_a
    end

    def scene_item_params
      params.expect(scene_item: [ :item_id, :role ])
    end

    # An update may carry either field on its own, so a role-only edit never clears
    # the link and an item-only edit never clears the role. A blank Item means
    # "keep the current one". A payload with neither field is malformed rather
    # than a no-op that would look like a successful save.
    def editable_scene_item_attributes
      attributes = scene_item_params
      resolved = {}
      resolved[:role] = attributes[:role] if attributes.key?(:role)

      item_id = attributes[:item_id]
      resolved[:item] = Current.universe.items.find(item_id) if item_id.present?

      raise ActionController::BadRequest, "a scene item update must change the item or the role" if resolved.empty?

      resolved
    end

    def scene_item_json(link)
      {
        id: link.id,
        item_id: link.item_id,
        role: link.role,
        url: universe_story_scene_scene_item_path(story_id: @story, scene_id: @scene, id: link)
      }
    end
end
