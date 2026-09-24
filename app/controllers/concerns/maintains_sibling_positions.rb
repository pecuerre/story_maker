module MaintainsSiblingPositions
  extend ActiveSupport::Concern

  class_methods do
    def maintains_sibling_positions_for(resource_name)
      define_method(:sibling_position_resource_name) { resource_name }
    end
  end

  private

  def sibling_count(parent_id)
    sibling_collection.where(parent_id: parent_id).where.not(id: sibling_position_resource&.id).count
  end

  def update_with_sibling_position(resource, attributes)
    requested_position = attributes[:position]
    old_parent_id = resource.parent_id

    return false unless resource.update(attributes.except(:position))

    if requested_position.present? || old_parent_id != resource.parent_id
      normalize_siblings(sibling_collection.where(parent_id: old_parent_id).order(:position, :id)) if old_parent_id != resource.parent_id
      siblings = resource.sibling_scope.to_a
      position = requested_position.present? ? requested_position.to_i.clamp(0, siblings.length) : siblings.length
      siblings.insert(position, resource)
      normalize_siblings(siblings)
    end

    true
  end

  def normalize_siblings(siblings)
    siblings.to_a.each_with_index { |sibling, index| sibling.update_columns(position: index) }
  end

  def sibling_collection
    Current.universe.public_send(sibling_position_resource_name.to_s.pluralize)
  end

  def sibling_position_resource
    instance_variable_get("@#{sibling_position_resource_name}")
  end
end
