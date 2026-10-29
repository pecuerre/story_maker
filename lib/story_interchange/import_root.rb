module StoryInterchange
  # The one directory the import page may read a source from, named by
  # `STORY_INTERCHANGE_IMPORT_ROOT`.
  #
  # The browser sends a folder *name*, never a path, and this class is what turns
  # that name into an absolute path only when it really is a child of the root.
  # `..`, a separator, a dot-file, and a symlink that resolves outside the root are
  # all refused, so the page cannot be turned into a reader of an arbitrary
  # directory. The command-line task takes its own path: whoever can run a shell
  # command already has more access than this restriction is meant to bound.
  class ImportRoot
    def initialize(path)
      @path = path.presence && File.expand_path(path)
    end

    # Whether the operator has configured a directory that exists. A configured
    # but missing path is not usable, and the page says so rather than offering
    # an empty list that looks like "no sources".
    def configured?
      @path.present? && File.directory?(@path)
    end

    # The source folders the page may offer, by name, sorted. A symlink is listed
    # only when it stays inside the root, which is the same rule `path_for` uses.
    def folders
      return [] unless configured?

      Dir.children(@path).sort.select { |name| path_for(name) }
    rescue SystemCallError
      []
    end

    # The absolute path of the named folder, or nil when it is not a real child
    # of the configured root.
    def path_for(name)
      return nil unless configured?

      name = name.to_s
      return nil if name.empty? || name.start_with?(".") || name.include?("/") || name.include?("\\")

      candidate = File.join(@path, name)
      return nil unless File.directory?(candidate)

      root = File.realpath(@path)
      real = File.realpath(candidate)
      return nil unless real.start_with?("#{root}#{File::SEPARATOR}")

      # The path keeps the *selected* name rather than the resolved one: the
      # source's directory name is its universe slug, and a symlink inside the
      # root is legitimate. The real path was checked above; following it for the
      # read is fine.
      candidate
    rescue SystemCallError, ArgumentError
      nil
    end
  end
end
