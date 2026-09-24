require "test_helper"
require "prism"

# Rails route helpers accept positional arguments, but the universe scope must remain explicit.
class UniverseRouteHelperArgumentsTest < ActiveSupport::TestCase
  ROUTE_HELPER_NAME = /\A(?:new_|edit_)?universe_[a-z0-9_]+_(?:path|url)\z/

  class CallVisitor < Prism::Visitor
    attr_reader :positional_calls

    def initialize(route_helper_name)
      @route_helper_name = route_helper_name
      @positional_calls = []
    end

    def visit_call_node(node)
      if node.name.to_s.match?(@route_helper_name) && positional_arguments?(node)
        @positional_calls << "#{node.location.start_line}: #{node.slice}"
      end

      super
    end

    private
      def positional_arguments?(node)
        (node.arguments&.arguments || []).any? do |argument|
          !argument.is_a?(Prism::KeywordHashNode)
        end
      end
  end

  test "universe route helpers use named arguments" do
    offenses = source_files.flat_map do |file|
      source = File.read(file)
      if file.end_with?(".erb")
        source = ActionView::Template::Handlers::ERB.erb_implementation.new(source, escape: false, trim: true).src
        # Layout templates use `yield`, which is valid in a compiled template method but not at
        # Ruby's top level. Wrapping the generated source keeps those templates parseable.
        source = "def __template__\n#{source}\nend"
      end

      result = Prism.parse(source)
      assert_empty result.errors, "Could not parse #{relative_path(file)}"

      visitor = CallVisitor.new(ROUTE_HELPER_NAME)
      result.value.accept(visitor)

      visitor.positional_calls.map do |offense|
        "#{relative_path(file)}:#{offense}"
      end
    end

    assert_empty offenses, <<~MESSAGE
      Universe-scoped route helpers must use named arguments. Rails assigns positional arguments
      to dynamic segments in order, so a Story passed to universe_story_sections_path would be
      assigned to universe_slug. Use a call such as
      universe_story_sections_path(story_id: story) instead.

      Offenses:
      #{offenses.join("\n")}
    MESSAGE
  end

  test "recognizes positional universe route calls without flagging named calls" do
    assert_equal [ "1: universe_story_sections_path(story)" ],
      scan("universe_story_sections_path(story)")
    assert_empty scan("universe_story_sections_path(story_id: story)")
    assert_empty scan("universe_story_sections_path(**options)")
    assert_empty scan("universe_story_sections_path")
    assert_empty scan("universe_characters_path")
  end

  private
    def source_files
      @source_files ||= %w[ app config lib test ].flat_map do |directory|
        Dir.glob(Rails.root.join(directory, "**", "*.{rb,erb}").to_s)
      end.sort
    end

    def scan(source)
      result = Prism.parse(source)
      assert_empty result.errors, "Could not parse test source"

      visitor = CallVisitor.new(ROUTE_HELPER_NAME)
      result.value.accept(visitor)
      visitor.positional_calls
    end

    def relative_path(file)
      file.delete_prefix("#{Rails.root}/")
    end
end
