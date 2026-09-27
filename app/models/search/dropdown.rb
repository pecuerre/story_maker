module Search
  # The client-side behaviour of the top-bar dropdown, in one place.
  #
  # These are view-facing: the box passes them to the Stimulus controller, and a
  # browser test has to know them to reproduce what a reader sees. The minimum
  # length is also the server's rule, so a request too short to be worth asking
  # about is short here too rather than being a second, disagreeing threshold.
  module Dropdown
    # One character matches most of a small universe. Two is the point where
    # results start to be about what was typed.
    MINIMUM_LENGTH = 2
    # Long enough that a burst of typing asks once, short enough that the
    # dropdown still feels like an answer rather than a wait.
    DELAY_MILLISECONDS = 150
  end
end
