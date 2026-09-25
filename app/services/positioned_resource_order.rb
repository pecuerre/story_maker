# Keeps ordered resource collections contiguous within a transaction. The
# service accepts both hierarchical collections (where parent_id scopes the
# siblings) and flat collections for future story-owned sequences.
class PositionedResourceOrder
  class << self
    def create(resource, collection, scope_owner:, parent_id:, requested_position: nil, hierarchical: true)
      result = false

      transaction_with_scope_lock(scope_owner) do
        resource.parent_id = parent_id if hierarchical && resource.respond_to?(:parent_id=)
        siblings = ordered_siblings(collection, parent_id, resource, hierarchical:)
        if requested_position.present?
          position = requested_position.to_i.clamp(0, siblings.length)
          siblings.insert(position, resource)
          resource.position = position
        else
          siblings << resource
          resource.position = siblings.length - 1
        end

        if resource.save
          normalize(siblings)
          result = true
        else
          raise ActiveRecord::Rollback
        end
      end

      result
    end

    def update(resource, attributes, collection, scope_owner:, hierarchical: true)
      result = false

      transaction_with_scope_lock(scope_owner) do
        resource.lock!
        old_parent_id = resource.parent_id if hierarchical
        requested_position = attributes[:position]

        resource.assign_attributes(attributes.except(:position))

        if resource.save
          new_parent_id = resource.parent_id if hierarchical
          parent_changed = hierarchical && old_parent_id.to_s != new_parent_id.to_s

          normalize(ordered_siblings(collection, old_parent_id, resource, hierarchical:)) if parent_changed

          if requested_position.present? || parent_changed
            siblings = ordered_siblings(collection, new_parent_id, resource, hierarchical:)
            position = requested_position.present? ? requested_position.to_i.clamp(0, siblings.length) : siblings.length
            siblings.insert(position, resource)
            normalize(siblings)
          end

          result = true
        else
          raise ActiveRecord::Rollback
        end
      end

      result
    end

    def destroy(resource, collection, scope_owner:, parent_id:, hierarchical: true)
      transaction_with_scope_lock(scope_owner) do
        resource.lock!
        resource.destroy!
        normalize(ordered_siblings(collection, parent_id, resource, hierarchical:))
      end

      true
    end

    private
      def transaction_with_scope_lock(scope_owner)
        ApplicationRecord.transaction(requires_new: true) do
          scope_owner&.lock!
          yield
        end
      end

      def ordered_siblings(collection, parent_id, resource, hierarchical:)
        scope = collection
        scope = scope.where(parent_id: parent_id) if hierarchical
        scope = scope.where.not(id: resource.id) if resource&.persisted?
        scope.reorder(:position, :id).lock.to_a
      end

      def normalize(siblings)
        siblings.each_with_index do |sibling, index|
          sibling.update_columns(position: index) unless sibling.position == index
        end
      end
  end
end
