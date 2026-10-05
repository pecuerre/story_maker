module CollaboratorsHelper
  # How many people have changed this universe, which is what the sidebar's
  # **Collaborators** entry carries.
  #
  # **It counts people, not changes.** That is the other half of the reason there are
  # two pages rather than one filtered page: this figure answers "how many people have
  # worked here" and the change history's answers "how many runs have happened", and a
  # single figure cannot be both. It is the size of the list
  # `CollaboratorsController#index` draws, so the sidebar and that page cannot disagree
  # about who counts as a collaborator.
  #
  # **It is deliberately uncached**, for the review queue's reason: it moves because a
  # run happened on some earlier request, and a `MenuCountCache` entry could hold a
  # figure that is wrong by however long its TTL is. One `COUNT` over one indexed
  # column, asked only by the readers who may see the page at all.
  #
  # Memoized for the length of the render, because nothing here is ever carried to a
  # later request.
  def collaborator_count
    return @collaborator_count if defined?(@collaborator_count)
    return @collaborator_count = 0 if Current.universe.nil?

    @collaborator_count = Collaborators.for(Current.universe).count
  end
end
