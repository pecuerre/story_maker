require "test_helper"

# The loader's two new jobs: a polymorphic reference, and a model with no slug of
# its own that a manifest still has to be able to reference.
#
# These drive `check!` rather than `load!`, because loading is development-only and
# the point here is the refusal: a manifest that hangs a thread off something which
# is not content, off a record that is not there, or off a second thread with the
# same name must fail with a sentence that says which. Manifests are written into a
# temporary directory so a refusal can be expressed without editing `db/data/`.
class UniverseDataLoaderPolymorphicTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir("universe-data-loader")
    @universe_dir = Pathname(@root).join("db/data/dark")
    FileUtils.mkdir_p(@universe_dir)
    # The catalog check requires every registered universe directory to exist, so
    # the one this test does not write still has to be there.
    FileUtils.mkdir_p(Pathname(@root).join("db/data/lotr"))
  end

  teardown do
    FileUtils.remove_entry(@root)
  end

  test "a thread about a content record and a reply from a user both resolve" do
    write_manifests(
      discussions: [ { universe: "Universe.dark", title: "Is she the heir?", record: "Character.martha" } ],
      discussion_messages: [
        { discussion: "Discussion.is-she-the-heir", user: "User.admin", body: "Keep the letter." }
      ]
    )

    assert_nothing_raised { check! }
  end

  test "a thread is identified by its title, because it has no slug of its own" do
    write_manifests(
      discussions: [
        { universe: "Universe.dark", title: "Who is the heir?", record: "Character.martha" },
        { universe: "Universe.dark", title: "Second thread", record: "Character.martha" }
      ],
      discussion_messages: [ { discussion: "Discussion.who-is-the-heir", user: "User.admin", body: "Martha." } ]
    )

    assert_nothing_raised { check! }
  end

  test "a thread cannot be hung off a model that is not content" do
    write_manifests(
      discussions: [ { universe: "Universe.dark", title: "About a person", record: "User.admin" } ]
    )

    error = assert_raises(Development::UniverseDataLoader::ValidationError) { check! }

    assert_match(/must reference a content model, not User/, error.message)
    assert_match(/discussions\.yml/, error.message)
  end

  test "a thread about a record the manifest does not define is refused" do
    write_manifests(
      discussions: [ { universe: "Universe.dark", title: "About nobody", record: "Character.nobody" } ]
    )

    error = assert_raises(Development::UniverseDataLoader::ValidationError) { check! }

    assert_match(/references missing Character\.nobody/, error.message)
  end

  test "a raw record id is refused in favour of the association name" do
    write_manifests(
      discussions: [ { universe: "Universe.dark", title: "By id", record_type: "Character", record_id: "1" } ]
    )

    error = assert_raises(Development::UniverseDataLoader::ValidationError) { check! }

    assert_match(/must use the association name instead of record_id/, error.message)
  end

  test "two threads with the same title are a duplicate reference rather than a silent overwrite" do
    write_manifests(
      discussions: [
        { universe: "Universe.dark", title: "Is she the heir?", record: "Character.martha" },
        { universe: "Universe.dark", title: "Is she the heir?", record: "Character.martha" }
      ]
    )

    error = assert_raises(Development::UniverseDataLoader::ValidationError) { check! }

    assert_match(/duplicate Discussion\.is-she-the-heir/, error.message)
  end

  test "a reply must name a thread that exists" do
    write_manifests(
      discussions: [],
      discussion_messages: [ { discussion: "Discussion.nothing", user: "User.admin", body: "Orphan." } ]
    )

    error = assert_raises(Development::UniverseDataLoader::ValidationError) { check! }

    assert_match(/references missing Discussion\.nothing/, error.message)
  end

  private

    def check!
      Development::UniverseDataLoader.new(universe: "dark", root: @root, verbose: false).check!
    end

    # `to_yaml` on symbol keys emits `:slug:`, which `YAML.safe_load_file` refuses,
    # and a manifest never contains one. Keys are stringified for the same reason.
    def write_yaml(file_name, rows)
      @universe_dir.join("#{file_name}.yml").write(
        rows.map { |row| row.transform_keys(&:to_s) }.to_yaml
      )
    end

    def write_manifests(discussions:, discussion_messages: [])
      # Every registered file, empty unless this test cares, so the loader's own
      # catalog check is satisfied rather than fought.
      Development::UniverseDataRegistry.file_names.each do |file_name|
        @universe_dir.join("#{file_name}.yml").write("[]\n")
      end

      write_yaml("users", [ { slug: "admin", name: "Admin", email_address: "admin@dark" } ])
      write_yaml("universes", [ { slug: "dark", name: "Dark", owner: "User.admin" } ])
      write_yaml("characters", [ { universe: "Universe.dark", name: "Martha" } ])
      write_yaml("discussions", discussions)
      write_yaml("discussion_messages", discussion_messages)
    end
end
