module SectionsHelper
  # A Section is edited by the shared taxonomy-tree editor. Its form carries the
  # name, parent, tags, photo, and a long description, so it opens the wide,
  # scrollable dialog the other record editors use rather than the narrow one a
  # tag taxonomy opens.
  def section_editor_dialog_class
    "modal-dialog modal-lg modal-dialog-scrollable"
  end
end
