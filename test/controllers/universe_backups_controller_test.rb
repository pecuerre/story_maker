require "test_helper"

class UniverseBackupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @owner = users(:user_one)
    @writer = users(:user_two)
    sign_in_as(@owner)
  end

  test "the owner can read the backup page" do
    get universe_backup_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: I18n.t("universe_backups.show.title")
    assert_select "a[href=?]", universe_backup_download_path(universe_slug: @universe.slug)
  end

  test "the universe page links an admin to the backup" do
    get universe_url(universe_slug: @universe.slug)

    assert_select "a[href=?]", universe_backup_path(universe_slug: @universe.slug), count: 1
  end

  test "the universe page does not link a plain writer to the backup" do
    sign_in_as(@writer)

    get universe_url(universe_slug: @universe.slug)

    assert_select "a[href=?]", universe_backup_path(universe_slug: @universe.slug), count: 0
  end

  test "the owner can download a tar.gz archive" do
    get universe_backup_download_url(universe_slug: @universe.slug)

    assert_response :success
    assert_equal "application/gzip", response.media_type
    assert_match(/attachment; filename="one-backup-\d{8}-\d{6}\.tar\.gz"/, response.headers["Content-Disposition"])
    assert_equal "no-store", response.headers["Cache-Control"]
    assert response.body.b.start_with?("\x1F\x8B".b)
  end

  test "a delegated admin can download the archive" do
    UniverseMembership.create!(universe: @universe, user: @writer, access_level: :admin)
    sign_in_as(@writer)

    get universe_backup_download_url(universe_slug: @universe.slug)

    assert_response :success
  end

  test "a plain writer is refused" do
    sign_in_as(@writer)

    get universe_backup_url(universe_slug: @universe.slug)
    assert_response :forbidden

    get universe_backup_download_url(universe_slug: @universe.slug)
    assert_response :forbidden
  end

  test "a guest is sent to sign in for a public universe" do
    sign_out

    get universe_backup_url(universe_slug: @universe.slug)

    assert_redirected_to new_session_url
  end

  test "a private universe is a 404 for a signed-in non-member" do
    @universe.update!(private: true)
    sign_in_as(@writer)

    get universe_backup_url(universe_slug: @universe.slug)

    assert_response :not_found
  end

  test "an unknown universe is a 404" do
    get universe_backup_url(universe_slug: "no-such-universe")

    assert_response :not_found
  end
end
