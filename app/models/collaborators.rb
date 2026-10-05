# Who has changed this universe, read from the drafts they closed.
#
# **A collaborator is an author with at least one closed draft here.** Not an open one:
# an open draft is pending work, it belongs to **Pending changes**, and it has not
# changed the universe yet. It is also not a membership row — a member who has never
# edited anything has not collaborated, and a person who has edited without being a
# member has (`Draft` is deliberately not a content class, so a public universe's writer
# never gets a membership row at all). So the list is read from `drafts`, which is the
# only table that says both things at once.
#
# **A discarded draft counts, and its changes count with it.** Omitting them would
# answer "who worked on this universe" with a list that drops everybody whose work was
# thrown away, which is the half a reader is likelier to be looking for. Nothing in the
# model marks those changes as never having existed, so what the count means is stated
# here rather than left to the page: **a remembered change, written or not**.
#
# **Two aggregates, one pass each, and never one query per person.** The sidebar asks
# how many people there are, the page asks how many changes each made, and the
# per-person page asks for one author's runs — so the counts are grouped in SQL and the
# names are loaded in one `where(id:)` rather than resolved per row.
class Collaborators
  # One person and what they have done here. `changes` counts remembered changes
  # across their closed drafts and `drafts` counts those drafts, and they are different
  # numbers on purpose: the page's figure is about changes because that is what the
  # reader is about to read, and the history sidebar's figure is about runs because
  # that is the unit the history page groups by.
  Entry = Struct.new(:user, :changes, :drafts, keyword_init: true)

  attr_reader :universe

  def initialize(universe:)
    @universe = universe
  end

  def self.for(universe)
    new(universe: universe)
  end

  # Everybody who has closed a draft here, most active first, then alphabetically so
  # two people with the same tally do not swap places between requests. Ordered in Ruby
  # because the names have to be loaded to sort by them and loading them per row would
  # be the query this class exists to avoid.
  def all
    return [] if universe.nil?

    drafts_by_user = universe.drafts.closed.group(:user_id).count
    changes_by_user = DraftChange.joins(:draft).merge(universe.drafts.closed).group("drafts.user_id").count

    users = User.where(id: drafts_by_user.keys).index_by(&:id)

    drafts_by_user.filter_map do |user_id, draft_count|
      user = users[user_id]
      next if user.nil?

      Entry.new(user: user, drafts: draft_count, changes: changes_by_user.fetch(user_id, 0))
    end.sort_by { |entry| [ -entry.changes, entry.user.name.downcase, entry.user.id ] }
  end

  # How many people there are, which is what the sidebar carries. It is the size of the
  # same list the page draws, so the figure and the page cannot disagree about who
  # counts as a collaborator.
  def count
    universe.nil? ? 0 : universe.drafts.closed.distinct.count(:user_id)
  end

  # One person's runs in this universe, newest first, or an empty list when they have
  # none here. **Scoped through the universe's closed drafts rather than looked up by
  # name**, so a user id from another universe is a person who has not collaborated
  # here rather than a page about somebody else's work.
  def drafts_for(user)
    return [] if universe.nil? || user.nil?

    universe.drafts.closed.where(user: user)
      .includes(:user, draft_changes: :outcome)
      .order(closed_at: :desc, id: :desc).to_a
  end

  # Whether this user has closed a draft here, which is the whole of what makes the
  # per-person page addressable. A user who has not is not a collaborator of this
  # universe and is answered with the same refusal as one who does not exist.
  def collaborator?(user)
    return false if universe.nil? || user.nil?

    universe.drafts.closed.where(user: user).exists?
  end
end
