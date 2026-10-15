# The request side of a filtered list: the recognized keys, the one-shot
# redirect to the canonical query, and the path a list-embedded mutation returns
# to.
#
# A workspace includes this, declares its filter with `filters_list_with`, and
# implements `#filtered_list_path_with`. Everything else — reading the query,
# deciding whether a submission needs canonicalizing, and reporting the values
# the filter dropped — is the same for every list, so it is written once.
#
# The rules are in [`docs/features/list_filters.md`](../../docs/features/list_filters.md).
module FilteredListQuery
  extend ActiveSupport::Concern

  class_methods do
    # Declares the filter this list narrows with, and reads its keys on the given
    # actions. Those actions are named rather than left to every caller, because
    # an in-list mutation is exactly what has to carry the filter back: reordering
    # or deleting inside a narrowed list should not dump the author on the full
    # one.
    def filters_list_with(filter_class, only:)
      @filter_class = filter_class
      before_action :set_filter_query, only: only
    end

    def filter_class
      @filter_class
    end
  end

  private
    # The recognized filter keys only. `slice` keeps the route, controller, and
    # action keys out, so permitting the rest cannot report anything the request
    # legitimately carries.
    def set_filter_query
      @filter_query = params.slice(*self.class.filter_class.params).permit(*self.class.filter_class.params)
    end

    # True when the request carried a filter key with no value, which is what a
    # plain form submission of the search area always looks like.
    def blank_filter_values?
      values = @filter_query.to_h
      values.compact_blank.size < values.size
    end

    # Redirecting once to the canonical query keeps the address bar, a bookmark,
    # and a shared link limited to the filters really in effect.
    def redirect_to_canonical_filtered_list
      redirect_to filtered_list_path_with(@list_filter.query_params), status: :found
    end

    # A list-embedded mutation returns to the same narrowed list when a filter is
    # in the URL. It carries the **requested** values rather than the resolved
    # ones, because this action does not build a filter; the index validates them
    # again on the way back.
    def filtered_list_path
      filtered_list_path_with(@filter_query.to_h.compact_blank)
    end

    # The discarded values are joined in the reader's language rather than in the
    # language the filter was built in, which is why the filter translated them
    # where it dropped them.
    def flash_discarded_filter_values
      return if @list_filter.discarded.empty?

      flash.now[:alert] = @list_filter.discarded.to_sentence
    end

    # The workspace's own index URL for a set of filter values: only the
    # recognized keys that carry a value, so a URL never depends on how the
    # search area was filled in.
    def filtered_list_path_with(_query)
      raise NotImplementedError,
        "#{self.class} must build its own filtered list URL in #filtered_list_path_with"
    end
end
