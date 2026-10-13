# The one row of configuration that belongs to the platform rather than to a
# universe.
#
# Every other budget in this application hangs off `universes`, because a universe's
# admins own it and there is always a universe to read it from. Universe
# **creation** is the one mutation with no universe yet: `POST /u` is counted
# before the row exists, so there is nothing for its ceiling to be stored on and
# nobody but an operator who could set it. This model is that ceiling's home.
#
# It is a singleton with one column rather than a key-value settings table, because
# a key-value store lets a typo become a setting nothing reads and turns every read
# into a string comparison. One row, one number, one reader.
#
# ## Why it is `NULL`-able
#
# The same rule as `universes.mutation_limit`, for the same reason: a column
# default protects every row from the moment it exists, and `NULL` is the one value
# an operator can store to mean "no limit at all" — which is a different setting
# from a number, and which a plain positive-integer column has nowhere to put.
#
# ## Why the reader answers a number even when the row stores `NULL`
#
# `universe_creation_limit` answers `DEFAULT_UNIVERSE_CREATION_LIMIT` for a `NULL`
# row, and `universe_creations_unlimited?` is what the throttle asks **first**. The
# apparent contradiction is the same one `Universe` resolves: the two answers are
# read for different questions — "how many may this account create" and "is this
# group limited at all" — and only the first is ever compared against a count.
class PlatformSetting < ApplicationRecord
  # How many universes one account may create per `UNIVERSE_CREATION_WINDOW` when
  # an operator has not configured a number of their own.
  #
  # Five per hour is chosen against what this application is for: an author
  # creates a universe to write in and rarely makes a second one, so the number is
  # far above ordinary work and far below what a script reaches in an afternoon.
  DEFAULT_UNIVERSE_CREATION_LIMIT = 5

  # The window `universe_creation_limit` is counted in. It is a constant rather than
  # a column for the reason every window in this application is: a window is not the
  # thing an operator has an opinion about, the number is. This one is an hour
  # rather than a minute because creating a universe is an act an author performs
  # once or twice, not once a minute — see ADR 0029.
  UNIVERSE_CREATION_WINDOW = 1.hour

  # `NULL` is the stored form of "no limit", `0` is refused for the same reason
  # `universes.mutation_limit` refuses it: zero creations is not what anybody means
  # by the field, and a platform nobody may create a universe on is not a setting
  # this field can express.
  validates :universe_creation_limit, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # The one row, or an unsaved one carrying the defaults.
  #
  # It does not create one on read: a `GET` that wrote would make every page load a
  # candidate for inserting a row, and a refusal to insert would turn a missing row
  # into a 500 on the one path that cannot afford one. A missing row answers the
  # default, the same way an incomplete universe row answers `DEFAULT_MUTATION_LIMIT`
  # rather than falling back to no limit.
  def self.current
    first || new
  end

  # The number to compare a count against, or the default for a row that stores
  # nothing. Ask `universe_creations_unlimited?` first — see the class comment.
  def universe_creation_limit
    self[:universe_creation_limit] || DEFAULT_UNIVERSE_CREATION_LIMIT
  end

  def universe_creations_unlimited?
    self[:universe_creation_limit].nil?
  end
end
