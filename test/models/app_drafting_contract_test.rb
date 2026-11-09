require "test_helper"

class AppDraftingContractTest < ActiveSupport::TestCase
  test "the known visibilities are exactly show and hide" do
    assert_equal %w[show hide], AppDraftingContract.names
    assert_equal "show", AppDraftingContract.default
  end

  test "only a known name is accepted" do
    assert AppDraftingContract.known?("hide")
    assert AppDraftingContract.known?(:hide)
    assert_not AppDraftingContract.known?("sometimes")
    assert_not AppDraftingContract.known?("")
    assert_not AppDraftingContract.known?(nil)
  end

  test "an unknown name reads, labels, and describes as the default" do
    cookie_jar = cookie_jar()

    assert_equal "Show", AppDraftingContract.label_for("sometimes")
    assert_equal "eye", AppDraftingContract.icon_for("sometimes")
    assert_predicate AppDraftingContract.description_for("sometimes"), :present?
    assert_equal "show", AppDraftingContract.read(cookie_jar)
    assert AppDraftingContract.visible?(cookie_jar)
  end

  test "a written visibility is read back and an unknown one is stored as the default" do
    cookie_jar = cookie_jar()

    AppDraftingContract.write(cookie_jar, "hide")
    assert_equal "hide", AppDraftingContract.read(cookie_jar)
    assert_not AppDraftingContract.visible?(cookie_jar)

    AppDraftingContract.write(cookie_jar, "sometimes")
    assert_equal "show", AppDraftingContract.read(cookie_jar)
    assert AppDraftingContract.visible?(cookie_jar)
  end

  test "an unsigned cookie cannot hide the note" do
    cookie_jar = cookie_jar()
    cookie_jar["um_drafting_contract"] = "hide"

    assert AppDraftingContract.visible?(cookie_jar)
  end

  test "every visibility has a label, an icon, and a description" do
    AppDraftingContract.names.each do |name|
      assert_predicate AppDraftingContract.label_for(name), :present?
      assert_predicate AppDraftingContract.icon_for(name), :present?
      assert_predicate AppDraftingContract.description_for(name), :present?
    end
  end

  private
    def cookie_jar
      ActionDispatch::TestRequest.create.cookie_jar
    end
end
