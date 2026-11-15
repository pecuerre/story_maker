require "test_helper"

# A photo is served by this application, not by Active Storage's own blob URL.
#
# The distinction is the whole access check: the framework's URL is signed for the
# blob and not for the reader, so it keeps working after access to a private
# Universe is revoked or after the person holding it shares it. Every request here
# therefore goes through the same Universe read policy a page does, and the answer
# is re-decided on every fetch.
class PhotosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @photo = create_photo(universe: @universe)
    @path = universe_photo_path(universe_slug: @universe.slug, id: @photo)
  end

  test "an authorized reader receives the stored bytes" do
    sign_in_as(users(:user_one))

    get @path

    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert_equal @photo.file.download, response.body
    assert_match(/inline/, response.headers["Content-Disposition"])
  end

  test "a guest may read a photo in a public universe" do
    get @path

    assert_response :success
  end

  test "a guest cannot read a private universe's photo" do
    @universe.update!(private: true)

    get @path

    assert_response :not_found
  end

  test "a signed-in non-member cannot read a private universe's photo" do
    @universe.update!(private: true)
    sign_in_as(users(:user_two))

    get @path

    assert_response :not_found
  end

  test "a member loses the photo when their access is revoked" do
    @universe.update!(private: true)
    membership = UniverseMembership.create!(
      universe: @universe, user: users(:user_two), access_level: :read)
    sign_in_as(users(:user_two))

    get @path
    assert_response :success, "the member should read the photo while the grant stands"

    membership.destroy!

    get @path
    assert_response :not_found, "the next request must ask again rather than trust a stored URL"
  end

  test "a photo from another universe is not found" do
    sign_in_as(users(:user_one))
    foreign = create_photo(universe: universes(:universe_two))

    get universe_photo_path(universe_slug: @universe.slug, id: foreign)

    assert_response :not_found
  end

  test "the response is not stored by the browser or a proxy" do
    get @path

    assert_response :success
    assert_includes response.headers["Cache-Control"].to_s, "private"
    assert_includes response.headers["Cache-Control"].to_s, "no-store"
  end

  test "Active Storage does not mount its own bearer route surface" do
    prefixes = Rails.application.routes.routes.map { |route| route.path.spec.to_s }

    assert_empty prefixes.grep(%r{\A/rails/active_storage}),
      "an Active Storage route would serve a photo from a signed URL that outlives the reader's access"
  end
end
