require "test_helper"

class TaxonomyTest < ActiveSupport::TestCase
  def setup
    @story = Story.create!(name: "Test Story", slug: "test-story")
    @taxonomy = @story.taxonomies.build(
      name: "Test Taxonomy",
      description: "A test taxonomy",
      slug: "test-taxonomy",
      fixed: false
    )
  end

  test "should be valid with valid attributes" do
    assert @taxonomy.valid?
  end

  test "should require name" do
    @taxonomy.name = nil
    assert_not @taxonomy.valid?
    assert_includes @taxonomy.errors[:name], "can't be blank"
  end

  test "should require unique name within story" do
    @taxonomy.save!
    duplicate = @story.taxonomies.build(name: "Test Taxonomy", slug: "different-slug")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should require slug" do
    @taxonomy.slug = nil
    assert_not @taxonomy.valid?
    assert_includes @taxonomy.errors[:slug], "can't be blank"
  end

  test "should require unique slug within story" do
    @taxonomy.save!
    duplicate = @story.taxonomies.build(name: "Different Name", slug: "test-taxonomy")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "should validate slug format" do
    @taxonomy.slug = "invalid slug with spaces"
    assert_not @taxonomy.valid?
    assert_includes @taxonomy.errors[:slug], "can only contain lowercase letters, numbers, and hyphens"

    @taxonomy.slug = "valid-slug-123"
    assert @taxonomy.valid?
  end

  test "should validate fixed boolean" do
    @taxonomy.fixed = nil
    @taxonomy.save!
    assert_equal false, @taxonomy.reload.fixed
  end

  test "should have many taxons" do
    @taxonomy.save!
    assert_respond_to @taxonomy, :taxons
  end

  test "should create root taxon after creation" do
    assert_difference "Taxon.count" do
      @taxonomy.save!
    end

    root_taxon = @taxonomy.taxons.first
    assert_equal @taxonomy.name, root_taxon.name
    assert_nil root_taxon.parent
    assert_equal @taxonomy, root_taxon.taxonomy
  end

  test "should destroy associated taxons when deleted" do
    @taxonomy.save!
    root_taxon = @taxonomy.taxons.first

    assert_difference "Taxon.count", -1 do
      @taxonomy.destroy
    end
  end

  test "should set default fixed value" do
    @taxonomy.fixed = nil
    @taxonomy.save!
    assert_equal false, @taxonomy.reload.fixed
  end

    test "should create fixed taxonomies for new story" do
    new_story = Story.create!(name: "New Story", slug: "new-story")
    assert_equal Taxonomy::FIXED_TAXONOMIES.length, new_story.taxonomies.count

    Taxonomy::FIXED_TAXONOMIES.each do |taxonomy_data|
      taxonomy = new_story.taxonomies.find_by(name: taxonomy_data[:name])
      assert_not_nil taxonomy
      assert taxonomy.fixed?
      assert_equal taxonomy_data[:is_story_taxonomy], taxonomy.is_story_taxonomy?
      assert_equal taxonomy_data[:is_setting_taxonomy], taxonomy.is_setting_taxonomy?
    end
  end
end
