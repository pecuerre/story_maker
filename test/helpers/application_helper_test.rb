require "test_helper"

class ApplicationHelperTest < ActiveSupport::TestCase
  include ApplicationHelper

  setup do
    @controller = Struct.new(:controller_name).new("characters")
  end

  test "visible? reports whether a requested controller is current" do
    assert visible?(:characters)
    assert_not visible?(:locations)
  end

  private
    def controller
      @controller
    end
end
