module MaintainsSiblingPositions
  extend ActiveSupport::Concern

  class_methods do
    def maintains_sibling_positions_for(resource_name, hierarchical: true)
      define_method(:sibling_position_resource_name) { resource_name }
      define_method(:sibling_position_hierarchical?) { hierarchical }
    end

    def maintains_flat_positions_for(resource_name)
      maintains_sibling_positions_for(resource_name, hierarchical: false)
    end
  end

  private

    def create_with_sibling_position(resource, requested_position: nil)
      PositionedResourceOrder.create(
        resource,
        sibling_collection,
        scope_owner: sibling_position_scope_owner,
        parent_id: position_parent_id_for(resource),
        requested_position: requested_position,
        hierarchical: sibling_position_hierarchical?
      )
    end

    def update_with_sibling_position(resource, attributes)
      PositionedResourceOrder.update(
        resource,
        attributes,
        sibling_collection,
        scope_owner: sibling_position_scope_owner,
        hierarchical: sibling_position_hierarchical?
      )
    end

    def destroy_with_sibling_position(resource)
      PositionedResourceOrder.destroy(
        resource,
        sibling_collection,
        scope_owner: sibling_position_scope_owner,
        parent_id: position_parent_id_for(resource),
        hierarchical: sibling_position_hierarchical?
      )
    end

    # Flat sequences (Story-owned Scenes and Scene Elements) have no ordering
    # parent, and a flat record has no `parent_id` column at all.
    def position_parent_id_for(resource)
      return unless sibling_position_hierarchical?
      return unless resource.respond_to?(:parent_id)

      resource.parent_id
    end

    def sibling_collection
      Current.universe.public_send(sibling_position_resource_name.to_s.pluralize)
    end

    def sibling_position_scope_owner
      Current.universe
    end
end
