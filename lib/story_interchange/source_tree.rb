module StoryInterchange
  # The one containment rule every read of a source tree obeys: a path is usable
  # only when, with every symlink followed, it is the source directory itself or
  # a child of it.
  #
  # `ImportRoot` applies this rule to the folder the page selected. This is the
  # same rule for the links *inside* that folder, which the source's own layout
  # can carry: a source may legitimately link a file or a directory it shares
  # with another, and the check is per path, so nothing is copied. A link that
  # leaves the tree is refused instead of followed, because following it would
  # turn the import into a reader of any file the server can open.
  #
  # The rule is checked against a path immediately before it is opened or walked.
  # A tree changed between that check and the read is not pinned by it; pinning
  # the tree would take a descriptor walk, which Ruby's standard library does not
  # expose.
  module SourceTree
    # Raised when a path resolves outside the tree, so the reader can report the
    # refusal instead of following it. The message is the sentence a report shows.
    class Outside < StandardError; end

    OUTSIDE_MESSAGE = "resolves outside the source directory and is not read".freeze

    module_function

    # The real path of `path` when it is `root` or a child of it, and nil when it
    # is outside. Both arguments must exist: a missing path has no real path and
    # raises, which is the caller's own existence case rather than containment.
    def real_path(root, path)
      resolved = File.realpath(path)

      resolved if inside?(File.realpath(root), resolved)
    end

    # `real_path`, refusing an escape by raising `Outside`.
    def resolve(root, path)
      real_path(root, path) || raise(Outside, OUTSIDE_MESSAGE)
    end

    # Whether `path`, already resolved, is `root` or a child of it. A root of `/`
    # contains every absolute path.
    def inside?(root, path)
      return true if root == path

      path.start_with?("#{root.delete_suffix(File::SEPARATOR)}#{File::SEPARATOR}")
    end
  end
end
