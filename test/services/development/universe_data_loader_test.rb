require "test_helper"
require "fileutils"
require "tmpdir"

class UniverseDataLoaderTest < ActiveSupport::TestCase
  test "checks every registered development universe without writing records" do
    assert_no_difference -> { User.count + Universe.count + Story.count } do
      Development::UniverseDataRegistry::UNIVERSES.each_key do |universe|
        Development::UniverseDataLoader.new(universe: universe, environment: :test).check!
      end
    end
  end

  test "supports a schema-independent preflight for reset" do
    assert_nothing_raised do
      Development::UniverseDataLoader.check!(universe: "dark", validate_schema: false, environment: :test)
    end
  end

  test "loads the Dark universe and normalizes sibling positions" do
    assert_difference -> { Universe.where(slug: "dark").count }, 1 do
      Development::UniverseDataLoader.new(universe: "dark", environment: :development, verbose: false).load!
    end

    universe = Universe.find_by!(slug: "dark")
    story = universe.stories.first

    assert_equal "Dark", universe.name
    assert_equal "Netflix Dark", story.name
    assert_equal "netflix-dark", story.slug
    assert_equal 15, story.sections.count
    assert_equal 4, story.scene_tags.count
    assert_equal 0, Universe.where(slug: "lotr").count
    assert_equal [ 0, 1, 2 ], story.sections.where(parent_id: nil).order(:position, :id).pluck(:position)
    assert_equal [ 0, 1, 2 ], story.section_tags.order(:position, :id).pluck(:position)
    assert_equal [ 0, 1 ], story.scene_tags.where(parent_id: nil).order(:position, :id).pluck(:position)
  end

  # The manifests used to carry a literal password, so a credential-shaped string
  # was part of the repository. The loader now owns the value: nothing under
  # `db/data` states one, and every account it creates authenticates with the
  # value the loader resolved for that load.
  test "the loader gives every user in the universe the password it resolved" do
    loader = Development::UniverseDataLoader.new(universe: "dark", environment: :development, verbose: false)
    loader.load!

    assert loader.password.generated?

    addresses = User.where(slug: %w[dark-admin dark-collaborator]).order(:slug).pluck(:email_address)
    assert_equal [ "dark@dark", "collaborator@dark" ], addresses

    addresses.each do |address|
      assert User.authenticate_by(email_address: address, password: loader.password.value),
        "the user #{address} must be able to sign in with the password the loader resolved"
    end
  end

  test "an exported development password is what every loaded user gets" do
    previous = ENV[Development::LocalPassword::ENV_KEY]
    ENV[Development::LocalPassword::ENV_KEY] = "a-password-the-developer-chose"

    loader = Development::UniverseDataLoader.new(universe: "lotr", environment: :development, verbose: false)
    loader.load!

    assert_not loader.password.generated?
    assert_equal "a-password-the-developer-chose", loader.password.value
    assert User.authenticate_by(email_address: "lotr@lotr", password: "a-password-the-developer-chose")
  ensure
    ENV[Development::LocalPassword::ENV_KEY] = previous
  end

  test "a user manifest that states a password is rejected" do
    with_data_copy do |directory|
      users_path = File.join(directory, "db/data/dark/users.yml")
      File.write(users_path, "#{File.read(users_path).chomp}\n  password: literal-in-a-manifest\n")

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/must not set password/, error.message)
      assert_match(/#{Development::LocalPassword::ENV_KEY}/, error.message)
    end
  end

  test "a user manifest that states a password confirmation is rejected" do
    with_data_copy do |directory|
      users_path = File.join(directory, "db/data/dark/users.yml")
      File.write(users_path, "#{File.read(users_path).chomp}\n  password_confirmation: literal-in-a-manifest\n")

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/must not set password_confirmation/, error.message)
    end
  end

  # The manifest rejection is what keeps a value out of the repository, so the
  # tracked text itself is asserted rather than only the loader's reaction to it.
  test "no checked-in development manifest states a password" do
    manifests = Dir[Rails.root.join("db/data/**/users.yml")]

    assert_not_empty manifests

    manifests.each do |path|
      assert_no_match(/^\s*password(_confirmation)?:/, Pathname(path).read,
        "#{path.delete_prefix("#{Rails.root}/")} states a password. The loader assigns it from " \
        "#{Development::LocalPassword::ENV_KEY}, or generates one for the load.")
    end
  end

  # Several stories in one universe is the shape the Dark directory exists to
  # show: the universe-level records are shared by all of them, while everything
  # story-scoped is each story's own.
  test "loads several stories into one universe with shared world records and per-story scope" do
    Development::UniverseDataLoader.new(universe: "dark", environment: :development, verbose: false).load!

    universe = Universe.find_by!(slug: "dark")

    assert_equal [ "Bethesda Dark", "Netflix Dark", "Netflix Darker" ], universe.stories.order(:slug).pluck(:name)
    assert_equal [ "bethesda-dark", "netflix-dark", "netflix-darker" ], universe.stories.order(:slug).pluck(:slug)
    # `netflix-dark` is first in stories.yml, so it is the first Story a reader
    # is offered, and the other two follow it rather than replacing it.
    assert_equal "Netflix Dark", universe.stories.order(:id).first.name

    # Universe-level records belong to the universe, so each story links the same
    # eight Locations and the same nine Characters rather than its own copies.
    # The three stories still reach different subsets of them, which is the
    # point: a shared record set is not a shared usage.
    assert_equal 9, universe.characters.count
    assert_equal 8, universe.locations.count
    linked_locations = universe.stories.sort_by { |story| story.slug }
      .map { |story| story.scenes.joins(:scene_locations).distinct.pluck(:location_id).sort }
    # Ordered by slug: bethesda-dark reaches four of the eight, netflix-dark
    # reaches all eight, and netflix-darker reaches five.
    assert_equal [ 4, 8, 5 ], linked_locations.map(&:size)
    assert_equal universe.locations.pluck(:id).sort, linked_locations.flatten.uniq.sort

    # Sections, tags, and scene positions are story-scoped, so each story has
    # its own of them and none of them leaks into a sibling. Ordered by slug:
    # bethesda-dark, netflix-dark, netflix-darker.
    assert_equal [ 4, 15, 5 ], universe.stories.order(:slug).map { |story| story.sections.count }
    assert_equal [ 5, 12, 5 ], universe.stories.order(:slug).map { |story| story.scenes.count }
    assert_equal [ 3, 3, 3 ], universe.stories.order(:slug).map { |story| story.section_tags.count }
    assert_equal [ 4, 4, 3 ], universe.stories.order(:slug).map { |story| story.scene_tags.count }

    darker = universe.stories.find_by!(slug: "netflix-darker")
    bethesda = universe.stories.find_by!(slug: "bethesda-dark")

    # Each story's scene sequence starts again at 0: `position` is narrative
    # order inside one story and is never a universe-wide running number.
    assert_equal [ 0, 1, 2, 3, 4 ], darker.scenes.reorder(:position, :id).pluck(:position)
    assert_equal [ 0, 1, 2, 3, 4 ], bethesda.scenes.reorder(:position, :id).pluck(:position)

    # Sections nest inside their own story only, and each story's taxonomy is its
    # own vocabulary rather than the same names repeated.
    assert_equal [ "Act One: The Hollow Tree", "Act Two: The Second Grave", "Cold Open" ],
      darker.sections.where(parent_id: nil).order(:position, :id).pluck(:name)
    assert_equal [ "Act", "Cold open" ], darker.section_tags.where(parent_id: nil).order(:position, :id).pluck(:name)
    assert_equal [ "Chapter", "Main quest" ], bethesda.section_tags.where(parent_id: nil).order(:position, :id).pluck(:name)
    assert_equal "Chapter", bethesda.section_tags.find_by!(slug: "side-quest").parent.name
    assert_equal "Act", darker.section_tags.find_by!(slug: "sequence").parent.name
    assert_equal "Act One: The Hollow Tree", darker.sections.find_by!(slug: "act1s1").parent.name
    # The sibling stories have no sections of the other's shape, because a
    # Section belongs to its Story and cannot be reached from a second one.
    assert_nil bethesda.sections.find_by(slug: "act1s1")
    assert_nil universe.stories.find_by!(slug: "netflix-dark").sections.find_by(slug: "act1s1")

    # A Story without a photo is a valid Story, so the third one has none while
    # the other two carry the universe's two checked-in images between them.
    assert_nil bethesda.photo
    assert_equal 2, universe.stories.where.not(photo_id: nil).distinct.count(:photo_id)
    assert_equal Photo.where(universe_id: universe.id).order(:id).pluck(:id),
      universe.stories.where.not(photo_id: nil).pluck(:photo_id).sort
  end

  test "loads the Dark scenes as a contiguous flat narrative sequence" do
    Development::UniverseDataLoader.new(universe: "dark", environment: :development, verbose: false).load!

    story = Universe.find_by!(slug: "dark").stories.first
    scenes = story.scenes.reorder(:position, :id).to_a

    assert_equal 12, scenes.size
    assert_equal (0...12).to_a, scenes.map(&:position)
    assert_equal "Secrets", scenes.first.name
    assert_equal "Interlude", scenes.last.name
    assert_equal [ "Mood", "Mystery" ], scenes.first.scene_tags.order(:position, :id).pluck(:name)
    assert_equal [ "Mystery" ], scenes[1].scene_tags.pluck(:name)
    assert_empty scenes[7].scene_tags

    assert_equal [ "Double Lives", "Interlude" ], scenes.select { |scene| scene.description.blank? }.map(&:name)
    assert_equal 0, Universe.where(slug: "lotr").joins(:stories).sum { |universe| universe.scenes.count }
  end

  test "loads the LOTR scenes in narrative order" do
    Development::UniverseDataLoader.new(universe: "lotr", environment: :development, verbose: false).load!

    story = Universe.find_by!(slug: "lotr").stories.first

    assert_equal 5, story.scenes.count
    assert_equal [ 0, 1, 2, 3, 4 ], story.scenes.reorder(:position, :id).pluck(:position)
    assert_equal "A Long-expected Party", story.scenes.reorder(:position, :id).first.name
    assert_equal [ "Adventure", "Fellowship" ], story.scenes.first.scene_tags.order(:position, :id).pluck(:name)
  end

  test "loads the LOTR universe with stable converted slugs" do
    Development::UniverseDataLoader.new(universe: "lotr", environment: :development, verbose: false).load!

    universe = Universe.find_by!(slug: "lotr")
    story = universe.stories.first

    assert_equal "The Lord of the Rings", story.name
    assert_equal "the-lord-of-the-rings", story.slug
    assert_equal [ "the-fellowship-of-the-ring", "the-two-towers", "the-return-of-the-king" ], story.sections.order(:position, :id).pluck(:slug)
  end

  test "loads the LOTR world-building records with nested locations and a chained timeline" do
    Development::UniverseDataLoader.new(universe: "lotr", environment: :development, verbose: false).load!

    universe = Universe.find_by!(slug: "lotr")

    assert_equal 7, universe.characters.count
    assert_equal 12, universe.locations.count
    assert_equal 5, universe.items.count
    assert_equal 6, universe.relations.count
    assert_equal 5, universe.ownerships.count
    assert_equal 6, universe.events.count

    # One relation and one ownership per universe carry the optional `name`, so the
    # field and the `display_string` preference for it are exercised by the loader
    # rather than only by the suite's own records.
    named_relation = universe.relations.find_by!(slug: "frodo-gollum")
    assert_equal "Bearer of the Ring", named_relation.name
    assert_equal "Bearer of the Ring", named_relation.display_string

    named_ownership = universe.ownerships.find_by!(slug: "aragorn-anduril")
    assert_equal "Heirloom of the House", named_ownership.name
    assert_equal "Heirloom of the House", named_ownership.display_string

    race = universe.character_tags.find_by!(name: "Race")
    hobbit = universe.character_tags.find_by!(name: "Hobbit")
    assert_equal race, hobbit.parent

    regions = universe.locations.where(name: %w[Eriador Rohan Gondor Mordor]).order(:position)
    assert_equal [ 0, 1, 2, 3 ], regions.pluck(:position)
    assert_equal "Mordor", universe.locations.find_by!(name: "Barad-dûr").parent.name

    ring = universe.ownerships.find_by!(slug: "frodo-one-ring")
    assert_equal universe.items.find_by!(name: "The One Ring"), ring.item
    assert_equal universe.characters.find_by!(name: "Frodo Baggins"), ring.character
    assert ring.from_date < ring.to_date

    leader_tag = universe.relation_tags.find_by!(name: "is leader of")
    assert_not leader_tag.symmetric?
    assert_equal "is led by", leader_tag.inverse

    timeline = universe.events.order(:position).to_a
    assert_equal "The Ring Is Given to Frodo", timeline.first.title
    timeline.each_cons(2) do |previous, event|
      assert_equal previous, event.after_event
    end
  end

  test "rejects loading outside the development environment" do
    error = assert_raises(Development::UniverseDataLoader::EnvironmentError) do
      Development::UniverseDataLoader.new(universe: "dark", environment: :production).load!
    end

    assert_match(/only be loaded in development/, error.message)
  end

  test "rejects unknown universes before touching the data directory" do
    error = assert_raises(Development::UniverseDataLoader::ValidationError) do
      Development::UniverseDataLoader.new(universe: "missing", environment: :test).check!
    end

    assert_match(/Unknown development universe/, error.message)
    assert_match(/dark, lotr/, error.message)
  end

  test "rejects missing symbolic references" do
    with_data_copy do |directory|
      characters_path = File.join(directory, "db/data/dark/characters.yml")
      contents = File.read(characters_path)
      File.write(characters_path, contents.sub("CharacterTag.family_kahnwald", "CharacterTag.missing"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/references missing CharacterTag\.missing/, error.message)
    end
  end

  test "rejects missing and unexpected model files" do
    with_data_copy do |directory|
      FileUtils.rm(File.join(directory, "db/data/dark/items.yml"))
      File.write(File.join(directory, "db/data/dark/extra.yml"), "[]\n")

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/missing: items\.yml/, error.message)
      assert_match(/unexpected: extra\.yml/, error.message)
    end
  end

  test "rejects raw foreign-key ids in association fields" do
    with_data_copy do |directory|
      characters_path = File.join(directory, "db/data/dark/characters.yml")
      contents = File.read(characters_path)
      File.write(characters_path, contents.sub("universe: Universe.dark", "universe: Universe.dark\n  universe_id: 1"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/use the association name instead of universe_id/, error.message)
    end
  end

  test "rejects non-string association values" do
    with_data_copy do |directory|
      universes_path = File.join(directory, "db/data/dark/universes.yml")
      contents = File.read(universes_path)
      File.write(universes_path, contents.sub("owner: User.dark_admin", "owner: 1"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/owner.*Model\.slug reference/, error.message)
    end
  end

  test "rejects scalar values for collection associations" do
    with_data_copy do |directory|
      characters_path = File.join(directory, "db/data/dark/characters.yml")
      contents = File.read(characters_path)
      File.write(characters_path, contents.sub("character_tags: [ CharacterTag.family_kahnwald, CharacterTag.sic_mundus ]", "character_tags: CharacterTag.family_kahnwald"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/character_tags.*array/, error.message)
    end
  end

  test "rejects references to the wrong association target class" do
    with_data_copy do |directory|
      ownerships_path = File.join(directory, "db/data/dark/ownerships.yml")
      contents = File.read(ownerships_path)
      File.write(ownerships_path, contents.sub("character: Character.jonas", "character: Item.jonas_key"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/must reference Character, not Item/, error.message)
    end
  end

  test "rejects a scene grouped under a section from another story" do
    with_data_copy do |directory|
      stories_path = File.join(directory, "db/data/dark/stories.yml")
      File.write(stories_path, "#{File.read(stories_path)}\n- universe: Universe.dark\n  name: Second story\n  slug: second-story\n")

      sections_path = File.join(directory, "db/data/dark/sections.yml")
      File.write(sections_path, "#{File.read(sections_path)}\n- story: Story.second-story\n  name: Elsewhere\n  slug: elsewhere\n")

      scenes_path = File.join(directory, "db/data/dark/scenes.yml")
      File.write(scenes_path, <<~YAML)
        - story: Story.netflix-dark
          name: Borrowed group
          slug: borrowed-group
          section: Section.elsewhere
          position: 0
      YAML

      # The Scene's own components belong to the manifest scenes that were just
      # replaced, so they are emptied rather than left referencing missing scenes.
      # A thread is the same: this one is about a Scene, so it goes too — and its
      # messages with it, because a reply to a thread that is not there is the same
      # dangling reference.
      %w[scene_elements scene_characters scene_items scene_locations discussions discussion_messages].each do |file|
        File.write(File.join(directory, "db/data/dark/#{file}.yml"), "[]\n")
      end

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/section must belong to the same story/, error.message)
    end
  end

  test "rejects a scene linked to an event from another universe" do
    with_data_copy do |directory|
      scenes_path = File.join(directory, "db/data/dark/scenes.yml")
      contents = File.read(scenes_path)
      File.write(scenes_path, contents.sub("event: Event.time_travel", "event: Event.ring_given_to_frodo"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/references missing Event\.ring_given_to_frodo/, error.message)
    end
  end

  test "rejects a scene component that cannot reach a scene" do
    with_data_copy do |directory|
      scenes_path = File.join(directory, "db/data/dark/scenes.yml")
      File.write(scenes_path, "[]\n")

      elements_path = File.join(directory, "db/data/dark/scene_elements.yml")
      File.write(elements_path, "- name: Orphan\n  kind: narration\n")

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/references missing Scene/, error.message)
    end
  end

  test "rejects an item presence link that points at the wrong record type" do
    with_data_copy do |directory|
      items_path = File.join(directory, "db/data/dark/scene_items.yml")
      contents = File.read(items_path)
      File.write(items_path, contents.sub("item: Item.jonas_key", "item: Character.jonas"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/field 'item' must reference Item, not Character/, error.message)
    end
  end

  test "rejects a location presence link that points at the wrong record type" do
    with_data_copy do |directory|
      locations_path = File.join(directory, "db/data/dark/scene_locations.yml")
      contents = File.read(locations_path)
      File.write(locations_path, contents.sub("location: Location.jonas_house", "location: Item.jonas_key"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/field 'location' must reference Location, not Item/, error.message)
    end
  end

  test "rejects an item presence link that resolves outside the target universe" do
    with_data_copy do |directory|
      items_path = File.join(directory, "db/data/dark/scene_items.yml")
      contents = File.read(items_path)
      File.write(items_path, contents.sub("item: Item.jonas_key", "item: Item.one_ring"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/references missing Item\.one_ring/, error.message)
    end
  end

  test "rejects a scene component that does not declare its scene" do
    with_data_copy do |directory|
      elements_path = File.join(directory, "db/data/dark/scene_elements.yml")
      File.write(elements_path, "- name: Orphan\n  kind: narration\n")

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/scene_elements\.yml:1 must declare its scene/, error.message)
    end
  end

  test "loads scene elements and presence links as connected, ordered records" do
    Development::UniverseDataLoader.new(universe: "dark", environment: :development, verbose: false).load!

    story = Universe.find_by!(slug: "dark").stories.first
    secrets = story.scenes.find_by!(slug: "secrets")
    waltz = story.scenes.find_by!(slug: "michaels-waltz")
    grotto = story.scenes.find_by!(slug: "the-grotto")

    # Element positions are contiguous inside their own Scene, and a Scene with
    # no elements is valid.
    assert_equal [ 0, 1, 2 ], secrets.scene_elements.reorder(:position, :id).pluck(:position)
    assert_equal [ 0, 1, 2 ], waltz.scene_elements.reorder(:position, :id).pluck(:position)
    assert_empty grotto.scene_elements

    dialogue = secrets.scene_elements.find_by!(kind: "dialogue")
    assert_equal [ "Katharina", "Martha" ], dialogue.characters.order(:name).pluck(:name)
    assert_predicate dialogue.body, :present?

    # A title-only narration loads with no content, which is a valid element.
    assert_nil secrets.scene_elements.find_by!(name: "The photograph").body
    # A single-speaker dialogue is as valid as the three-speaker one.
    assert_equal [ "Jonas" ], waltz.scene_elements.find_by!(kind: "dialogue").characters.pluck(:name)

    # Presence links carry a free-text role, and a blank role loads as no role.
    link = secrets.scene_characters.find_by!(character: story.universe.characters.find_by!(slug: "martha"))
    assert_equal "opens the door", link.role
    assert_nil waltz.scene_characters.find_by!(character: story.universe.characters.find_by!(slug: "jonas")).role

    # Katharina speaks in the dialogue above and is deliberately not a stored
    # participant, so the derived and stored sources stay distinguishable.
    assert_not_includes secrets.scene_characters.pluck(:character_id),
      story.universe.characters.find_by!(slug: "katharina").id
    participants = SceneParticipants.for(secrets)
    assert_equal [ "Jonas", "Katharina", "Martha" ], participants.entries.map { |entry| entry.character.name }
    assert_equal 3, participants.count
  end

  test "the Lord of the Rings manifest loads four speakers into one dialogue" do
    Development::UniverseDataLoader.new(universe: "lotr", environment: :development, verbose: false).load!

    story = Universe.find_by!(slug: "lotr").stories.first
    council = story.scenes.find_by!(slug: "the-council-of-elrond")

    assert_equal [ 0, 1, 2 ], council.scene_elements.reorder(:position, :id).pluck(:position)
    dialogue = council.scene_elements.find_by!(kind: "dialogue")
    assert_equal [ "Aragorn", "Gandalf the Grey", "Gimli", "Legolas" ], dialogue.characters.order(:name).pluck(:name)
    # Legolas and Gimli speak here without ever being stored as participants.
    assert_equal [ "Aragorn", "Frodo Baggins" ], council.scene_characters.includes(:character)
      .map { |link| link.character.name }.sort
  end

  test "loads item and location presence as connected records with free-text roles" do
    Development::UniverseDataLoader.new(universe: "dark", environment: :development, verbose: false).load!

    universe = Universe.find_by!(slug: "dark")
    story = universe.stories.first
    secrets = story.scenes.find_by!(slug: "secrets")
    interlude = story.scenes.find_by!(slug: "interlude")

    # The same item is linked into two scenes, and one scene holds two items, so
    # neither the unique-per-scene index nor the plural tab is exercised only in
    # its simplest case. Scoped to this Story: an Item belongs to the universe
    # and the sibling stories link it too.
    god_particle_scenes = story.scenes.joins(scene_items: :item)
      .where(items: { name: "The God Particle" }).order(:position, :id).pluck(:name)
    assert_equal [ "Truths", "Sic Mundus Creatus Est" ], god_particle_scenes
    assert_equal [ "Sphere Machine", "The God Particle" ],
      story.scenes.find_by!(slug: "sic-mundus-creatus-est").scene_items.includes(:item)
        .map { |link| link.item.name }.sort
    assert_equal "carries the box", secrets.scene_items.joins(:item)
      .find_by(items: { name: "Jonas Key" }).role
    # A blank role loads as no role rather than an empty annotation.
    assert_nil story.scenes.find_by!(slug: "lies").scene_items.joins(:item)
      .find_by(items: { name: "Jonas Key" }).role

    # Locations nest, so the tab has to name each linked place with its ancestor
    # path. One scene holds a top-level place, a nested room, and a region, and
    # one of the three deliberately has no role.
    paths = LocationPaths.build(universe.locations.reorder(:position, :id).to_a)
    waltz = story.scenes.find_by!(slug: "michaels-waltz").scene_locations.includes(:location).to_a
    assert_equal [ "Winden / Nielsen House", "Winden / Nielsen House / Magnus Room" ],
      waltz.map { |link| paths.label_for(link.location) }.sort
    assert_equal "dances in the kitchen", waltz.find { |link| link.location.name == "Nielsen House" }.role
    assert_nil waltz.find { |link| link.location.name == "Magnus Room" }.role

    # Both tabs reach their empty state without inventing a record.
    assert_empty interlude.scene_items
    assert_empty interlude.scene_locations
  end

  test "loads the Lord of the Rings item and location presence links" do
    Development::UniverseDataLoader.new(universe: "lotr", environment: :development, verbose: false).load!

    universe = Universe.find_by!(slug: "lotr")
    story = universe.stories.first
    party = story.scenes.find_by!(slug: "a-long-expected-party")
    walk = story.scenes.find_by!(slug: "a-long-walk-in-the-dark")

    assert_equal [ "Sting", "The One Ring" ], party.scene_items.includes(:item)
      .map { |link| link.item.name }.sort
    assert_equal "on the table", party.scene_items.joins(:item).find_by(items: { name: "The One Ring" }).role
    # A nested place beside the region it sits in, one of them with no role.
    assert_equal [ "Eriador", "Rivendell" ], story.scenes.find_by!(slug: "the-council-of-elrond")
      .scene_locations.includes(:location).map { |link| link.location.name }.sort
    assert_empty walk.scene_items
    assert_empty walk.scene_locations
  end

  test "rejects a scene tag from another story" do
    with_data_copy do |directory|
      stories_path = File.join(directory, "db/data/dark/stories.yml")
      File.write(stories_path, "#{File.read(stories_path)}\n- universe: Universe.dark\n  name: Second story\n  slug: second-story\n")

      scene_tags_path = File.join(directory, "db/data/dark/scene_tags.yml")
      File.write(scene_tags_path, "#{File.read(scene_tags_path)}\n- story: Story.second-story\n  name: Foreign scene tag\n  slug: foreign-scene-tag\n")

      scenes_path = File.join(directory, "db/data/dark/scenes.yml")
      contents = File.read(scenes_path)
      File.write(scenes_path, contents.sub("scene_tags: [ SceneTag.mood, SceneTag.mystery ]", "scene_tags: [ SceneTag.foreign-scene-tag ]"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/tag 'foreign-scene-tag' must belong to the same story/, error.message)
    end
  end

  test "loads Scene grouping and in-world references from the manifests" do
    Development::UniverseDataLoader.new(universe: "dark", environment: :development, verbose: false).load!

    story = Universe.find_by!(slug: "dark").stories.first
    scenes = story.scenes.reorder(:position, :id).to_a
    paths = SectionPaths.build(story.sections.reorder(:position, :id).to_a)

    assert_equal "Season 1 / Episode 1: Secrets", paths.label_for(scenes.first.section_id)
    assert_equal "Jonas meets Bartosz - 2024-01-01 10:00", scenes.first.event.display_string
    assert_equal Time.utc(1986, 9, 1, 10), scenes.first.datetime

    # A datetime without an event, an event without a datetime, and shared events.
    assert_nil scenes[4].event
    assert_equal Time.utc(2019, 11, 5, 21), scenes[4].datetime
    assert_equal scenes[6].event, scenes[7].event
    assert_equal scenes[0].event, scenes[2].event

    # A title-only, ungrouped scene.
    assert_equal "Double Lives", scenes[5].name
    assert_nil scenes[5].section
    assert_nil scenes[5].event
    assert_nil scenes[5].datetime
  end

  test "loads grouped and ungrouped Dark scenes so grouping and order stay separate" do
    Development::UniverseDataLoader.new(universe: "dark", environment: :development, verbose: false).load!

    story = Universe.find_by!(slug: "dark").stories.first
    scenes = story.scenes.reorder(:position, :id).to_a
    paths = SectionPaths.build(story.sections.reorder(:position, :id).to_a)

    # Several scenes share one section, and one scene is still alone in a section
    # of its own, so both shapes can be exercised in the browser.
    first_episode = "Season 1 / Episode 1: Secrets"
    assert_equal [ "Secrets", "The Search in the Woods", "Michael's Waltz" ],
      scenes.select { |scene| paths.label_for(scene.section_id) == first_episode }.map(&:name)
    assert_equal [ "Lies" ], scenes.select { |scene| paths.label_for(scene.section_id) == "Season 1 / Episode 2: Lies" }
      .map(&:name)

    # Several scenes are ungrouped, including one told last that happens first.
    assert_equal [ "Double Lives", "The Grotto", "Interlude" ],
      scenes.select { |scene| scene.section_id.nil? }.map(&:name)
    grotto = scenes.find { |scene| scene.name == "The Grotto" }
    assert_operator grotto.datetime, :<, scenes.first.datetime
  end

  test "rejects references to records outside the selected universe" do
    with_data_copy do |directory|
      sections_path = File.join(directory, "db/data/dark/sections.yml")
      contents = File.read(sections_path)
      File.write(sections_path, contents.sub("story: Story.netflix-dark", "story: Story.the-lord-of-the-rings"))

      error = assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :test).check!
      end

      assert_match(/references missing Story\.the-lord-of-the-rings/, error.message)
    end
  end

  test "rolls back all records when a model validation fails late in the load" do
    with_data_copy do |directory|
      event_tags_path = File.join(directory, "db/data/dark/event_tags.yml")
      contents = File.read(event_tags_path)
      File.write(event_tags_path, contents.sub('bgcolor: "#3357FF"', 'bgcolor: "not-a-color"'))

      assert_raises(Development::UniverseDataLoader::ValidationError) do
        Development::UniverseDataLoader.new(universe: "dark", root: directory, environment: :development, verbose: false).load!
      end

      assert_not Universe.exists?(slug: "dark")
    end
  end

  test "refuses to load a universe that already exists" do
    user = User.create!(name: "Existing owner", email_address: "existing-owner@example.com", password: "password")
    Universe.create!(name: "Existing Dark", slug: "dark", owner: user, private: false)

    error = assert_raises(Development::UniverseDataLoader::ValidationError) do
      Development::UniverseDataLoader.new(universe: "dark", environment: :development, verbose: false).load!
    end

    assert_match(/already exists/, error.message)
  end

  private
    def with_data_copy
      Dir.mktmpdir("universe-data") do |directory|
        data_root = File.join(directory, "db/data")
        FileUtils.mkdir_p(data_root)
        FileUtils.cp_r(Rails.root.join("db/data/dark"), File.join(data_root, "dark"))
        FileUtils.cp_r(Rails.root.join("db/data/lotr"), File.join(data_root, "lotr"))
        yield directory
      end
    end
end
