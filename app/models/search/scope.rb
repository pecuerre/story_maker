module Search
  # The scope dropdown: what a search is allowed to look at.
  #
  # A scope is either a *boundary* — the whole platform, the current universe, the
  # current story — or a *kind* ("only characters"). A kind is always searched
  # inside a boundary, so inside a universe "only characters" means this
  # universe's characters, and on the landing page it means the ones the visitor
  # may read. That is why a kind option declares `:inherited` rather than a
  # boundary of its own.
  #
  # A scope is resolved, never trusted. Asking for this story without a selected
  # story degrades to the widest boundary that does exist and says so, in the
  # same way `SceneFilter` reports a value it could not use, instead of
  # returning an empty list that looks like "nothing matched".
  class Scope
    # A boundary option's own value is also the boundary it requires.
    PLATFORM = "platform"
    UNIVERSE = "universe"
    STORY = "story"

    Option = Data.define(:value, :label, :kind, :boundary, :commands)

    OPTIONS = [
      Option.new(value: PLATFORM, label: "Entire platform", kind: nil, boundary: :platform, commands: true),
      Option.new(value: UNIVERSE, label: "This universe", kind: nil, boundary: :universe, commands: true),
      Option.new(value: STORY, label: "This story", kind: nil, boundary: :story, commands: true),
      Option.new(value: "universes", label: "Only universes", kind: "universe", boundary: :inherited, commands: false),
      Option.new(value: "stories", label: "Only stories", kind: "story", boundary: :inherited, commands: false),
      Option.new(value: "characters", label: "Only characters", kind: "character", boundary: :inherited, commands: false),
      Option.new(value: "locations", label: "Only locations", kind: "location", boundary: :inherited, commands: false),
      Option.new(value: "items", label: "Only items", kind: "item", boundary: :inherited, commands: false),
      Option.new(value: "events", label: "Only events", kind: "event", boundary: :inherited, commands: false),
      Option.new(value: "relations", label: "Only relations", kind: "relation", boundary: :inherited, commands: false),
      Option.new(value: "ownerships", label: "Only ownerships", kind: "ownership", boundary: :inherited, commands: false),
      Option.new(value: "sections", label: "Only sections", kind: "section", boundary: :inherited, commands: false),
      Option.new(value: "scenes", label: "Only scenes", kind: "scene", boundary: :inherited, commands: false),
      Option.new(value: "tags", label: "Only tags", kind: "tag", boundary: :inherited, commands: false)
    ].freeze

    VALUES = OPTIONS.map(&:value).freeze

    attr_reader :value, :option, :boundary, :universe, :story, :discarded

    def initialize(value, universe: nil, story: nil)
      @discarded = []
      @universe = universe
      @story = story
      @option = self.class.option_for(value)
      @value = @option&.value
      unless @option
        # A missing scope is the normal case — the form simply has nothing to say
        # — so only a scope that *was* asked for and is not one of ours is worth
        # reporting. It came from a hand-edited URL.
        @discarded << "“#{value}” is not a search scope, so the default scope was used." if value.present?
        @option = self.class.option_for(default_value)
        @value = @option.value
      end
      @boundary = resolve_boundary
      report_degradation
    end

    def self.option_for(value)
      OPTIONS.find { |option| option.value == value.to_s } if value.present?
    end

    # Whether an option can mean what it says right now. "This universe" on the
    # landing page and "this story" without a story are the two that cannot, and
    # both are disabled rather than hidden: the shape of the dropdown then stays
    # the same everywhere, and a reader can see those searches exist.
    def self.available?(option, universe: nil, story: nil)
      case option.boundary
      when :universe then universe.present?
      when :story then story.present?
      else true
      end
    end

    # Universe and story only make sense inside a universe page. On the landing
    # page the platform is the widest boundary that exists, so it is the default
    # there and "this universe" is the default everywhere else.
    def self.default_for(universe)
      universe ? UNIVERSE : PLATFORM
    end

    def kind
      option&.kind
    end

    def kind?
      kind.present?
    end

    # Navigation commands belong to a boundary search: someone typing "hobbit"
    # wants records, while someone typing "chara" wants the Characters page. A
    # search narrowed to one kind has already said what they are looking for.
    def commands?
      option&.commands == true
    end

    def label
      option&.label
    end

    # The scope a control should show. It is `value` — the scope that was asked
    # for — until that scope is one this page cannot honour: a story search with
    # no story selected was widened, and displaying "this story" as a disabled,
    # selected option would describe a search that is not happening. The request
    # keeps `value` in its URL, so choosing a story afterwards is still one click.
    def display_value
      return value if self.class.available?(option, universe: universe, story: story)

      self.class.default_for(universe)
    end

    def story?
      boundary == STORY
    end

    def universe?
      boundary == UNIVERSE
    end

    private
      def default_value
        self.class.default_for(universe)
      end

      def resolve_boundary
        requested = option.boundary
        case requested
        when :inherited then inherited_boundary
        when :universe then universe ? UNIVERSE : PLATFORM
        when :story then story ? STORY : (universe ? UNIVERSE : PLATFORM)
        else PLATFORM
        end
      end

      # A kind search follows the page: inside a universe it stays inside it, and
      # on the landing page it spans what the visitor may read.
      def inherited_boundary
        universe ? UNIVERSE : PLATFORM
      end

      def report_degradation
        return unless option.boundary == :story && story.nil?

        @discarded << if universe
          "The story search was widened to this universe because no story is selected."
        else
          "The story search was widened to the entire platform because no story is selected."
        end
      end
  end
end
