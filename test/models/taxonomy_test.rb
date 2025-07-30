require "test_helper"

class TaxonomyTest < ActiveSupport::TestCase
  def setup
    @taxonomy = Taxonomy.new(
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

  test "should require unique name" do
    @taxonomy.save!
    duplicate = Taxonomy.new(name: "Test Taxonomy", slug: "different-slug")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should require slug" do
    @taxonomy.slug = nil
    assert_not @taxonomy.valid?
    assert_includes @taxonomy.errors[:slug], "can't be blank"
  end

  test "should require unique slug" do
    @taxonomy.save!
    duplicate = Taxonomy.new(name: "Different Name", slug: "test-taxonomy")
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
end
