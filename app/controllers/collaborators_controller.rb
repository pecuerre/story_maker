# Who has changed this universe, and what one of them changed.
#
# **Both actions ask for `admin` on the universe**, through `UniverseAuthorization`, on
# the review queue's reasoning rather than the drafts pages'. Those answer "may this
# person see and act on their own pending work"; these answer "may this person see what
# other people have done here". The list is itself the answer — it names every author
# who has ever closed a draft in this universe — and the per-person page carries the
# same payload a closed draft carries, including the runs that were discarded.
#
# **Two actions rather than one page with a filter.** The sidebar figure has to count
# *people* and the list's own figure has to count *changes*, and a filtered
# universe-wide page would have to be correct about both, in the chrome, for a filter
# that is not part of either answer. Two views also let the per-person page say whose
# history it is, which is the question it exists to answer.
#
# **The per-person page reuses the universe history's own day grouping and rows.** The
# two are the same reading at two scopes, so `histories/_day` and `drafts/_change` are
# shared and the two pages cannot come to disagree about what one run did. The only
# difference is that the author is already named in the page's own heading, so the rows
# do not repeat it.
class CollaboratorsController < ApplicationController
  before_action :set_collaborator, only: :show

  # GET /u/:universe_slug/collaborators
  #
  # Everybody who has closed a draft in this universe, most active first, each with the
  # number of remembered changes they have made.
  def index
    @collaborators = collaborators.all
  end

  # GET /u/:universe_slug/collaborators/:id
  #
  # One person's closed drafts in this universe, grouped by the day each one closed —
  # the same page as the universe's history, narrowed to an author.
  #
  # **A user who has not collaborated here is a 404, not an empty page.** They are not
  # a collaborator of this universe, and answering with an empty list would confirm that
  # a user id exists and is somebody's business in a way that is not this page's to
  # give. The lookup is therefore scoped through the universe's closed drafts, which
  # makes "not a collaborator" and "does not exist" one answer.
  def show
    @drafts = collaborators.drafts_for(@collaborator)
    @changes = @drafts.flat_map(&:draft_changes)
  end

  private
    # The reader's own view of who has worked here, built once per request. Memoized on
    # the controller rather than per call because `index` asks for the list and the page
    # header's figure asks for its size, and those are one answer rather than two.
    def collaborators
      @collaborators_query ||= Collaborators.for(Current.universe)
    end

    def set_collaborator
      candidate = User.find_by(id: params.expect(:id))
      raise ActiveRecord::RecordNotFound, "Collaborator not found" unless collaborators.collaborator?(candidate)

      @collaborator = candidate
    end
end
