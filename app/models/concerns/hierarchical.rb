module Hierarchical
  extend ActiveSupport::Concern

  included do
    belongs_to :parent, class_name: name, optional: true
    has_many :children, -> { order(:position, :id) },
             class_name: name,
             foreign_key: :parent_id,
             dependent: :destroy

    validate :parent_reference_exists
    validate :parent_belongs_to_same_universe
    validate :parent_cannot_be_self
    validate :parent_cannot_be_descendant
    validate :scope_change_does_not_orphan_children

    after_destroy :normalize_sibling_positions_after_destroy
  end

  def root?
    parent_id.nil?
  end

  def sibling_scope
    hierarchy_scope.public_send(self.class.table_name).where(parent_id: parent_id).where.not(id: id).order(:position, :id)
  end

  def ancestor_chain
    node = parent
    result = []
    visited = []

    while node && !visited.include?(node)
      result << node
      visited << node
      node = node.parent
    end

    result
  end

  # All descendant tag IDs (children, grandchildren, etc.) in the subtree.
  def descendant_ids
    children.flat_map { |child| [ child.id, *child.descendant_ids ] }
  end

  private

  # Ownership scope parents must share. Defaults to the universe; models that
  # belong to something narrower (Section belongs_to :story) override these.
  def hierarchy_scope
    universe
  end

  def hierarchy_scope_attribute
    :universe_id
  end

  # The *key* of the scope sentence, not the sentence: a model that narrows the
  # scope overrides this to name the other key rather than to write its own
  # English, which is what let three models each carry a copy of a word a locale
  # cannot choose. See `shared.errors.same_scope`.
  def hierarchy_scope_error_key
    "shared.errors.same_scope.universe"
  end

  # An optional reference is only optional when it is *absent*. A `parent_id`
  # the reader typed resolves to no record, so every rule above reads it as "no
  # parent" and the write is refused by the database's foreign key instead — an
  # unhandled 500 rather than the documented error hash. This is the rule
  # `Scene` already applies to its own optional links
  # (`Scene#optional_references_exist`): a submitted id that names nothing is a
  # field error on the field that carried it, so the editor renders it beside the
  # control instead of losing the submission.
  #
  # It is deliberately not limited to a change in `parent_id`. A record whose
  # parent was soft-deleted or removed keeps the column, and re-saving it must
  # say so rather than silently pass a dangling reference back to the database.
  # Every model with a hierarchy declares `soft_deletes :children`, so an ordinary
  # delete clears the reference instead of orphaning a live child.
  def parent_reference_exists
    return unless parent_id.present? && parent.nil?

    errors.add(:parent, I18n.t("shared.errors.hierarchy.must_exist"))
  end

  def parent_belongs_to_same_universe
    return if parent.nil? ||
      parent.public_send(hierarchy_scope_attribute) == public_send(hierarchy_scope_attribute)

    errors.add(:parent, I18n.t(hierarchy_scope_error_key))
  end

  # A hierarchical record's whole subtree lives in the same owning scope (universe,
  # or story for Section/SectionTag/SceneTag). Moving the record itself would leave
  # every child behind in the old scope, which violates the graph-wide scope rules,
  # so a scope change is rejected while child records exist. Move the subtree
  # leaf-up instead.
  def scope_change_does_not_orphan_children
    return unless will_save_change_to_attribute?(hierarchy_scope_attribute)
    return unless children.exists?

    errors.add(hierarchy_scope_attribute, I18n.t("shared.errors.hierarchy.scope_change_with_children"))
  end

  def parent_cannot_be_self
    errors.add(:parent, I18n.t("shared.errors.hierarchy.cannot_be_itself")) if parent.present? && parent == self
  end

  def parent_cannot_be_descendant
    return if parent.nil? || new_record? || parent_id == id

    errors.add(:parent, I18n.t("shared.errors.hierarchy.cannot_be_descendant")) if parent.ancestor_chain.include?(self)
  end

  def normalize_sibling_positions_after_destroy
    scope = hierarchy_scope
    return unless scope&.persisted?

    siblings = scope.public_send(self.class.table_name)
      .where(parent_id: parent_id)
      .where.not(id: id)
      .reorder(:position, :id)
      .lock

    siblings.each_with_index do |sibling, index|
      sibling.update_columns(position: index) unless sibling.position == index
    end
  end
end
