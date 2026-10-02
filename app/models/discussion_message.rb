# One message in one conversation.
#
# The author is stored rather than inferred, and `body` is plain text: the
# collaboration plan defers markdown in discussions, so there is no rendered form
# to keep safe here yet. A future formatting slice changes this model and nothing
# else, because the thread already knows which record it belongs to.
#
# Whether the author may write at all is not decided here. It is an authorization
# question about the thread's record, asked by the controller through `Ability`;
# a model cannot know who is signed in.
class DiscussionMessage < ApplicationRecord
  belongs_to :discussion
  belongs_to :user

  validates :body, presence: true
end
