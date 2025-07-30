require "test_helper"

class TaxonTest < ActiveSupport::TestCase
  def setup
    @taxonomy = Taxonomy.create!(
      name: "Test Taxonomy",
      description: "A test taxonomy",
      slug: "test-taxonomy",
      fixed: false
    )
    @root_taxon = @taxonomy.taxons.first
    @child_taxon = @taxonomy.taxons.create!(name: "Child Taxon", parent: @root_taxon)
    @grandchild_taxon = @taxonomy.taxons.create!(name: "Grandchild Taxon", parent: @child_taxon)
  end

  test "should be valid with valid attributes" do
    assert @child_taxon.valid?
  end

  test "should require name" do
    @child_taxon.name = nil
    assert_not @child_taxon.valid?
    assert_includes @child_taxon.errors[:name], "can't be blank"
  end

  test "should require taxonomy" do
    @child_taxon.taxonomy = nil
    assert_not @child_taxon.valid?
    assert_includes @child_taxon.errors[:taxonomy], "must exist"
  end

  test "should belong to taxonomy" do
    assert_respond_to @child_taxon, :taxonomy
    assert_equal @taxonomy, @child_taxon.taxonomy
  end

  test "should belong to parent taxon" do
    assert_respond_to @child_taxon, :parent
    assert_equal @root_taxon, @child_taxon.parent
  end

  test "should have many children" do
    assert_respond_to @root_taxon, :children
    assert_includes @root_taxon.children, @child_taxon
  end

  test "should identify root taxons" do
    assert @root_taxon.root?
    assert_not @child_taxon.root?
  end

  test "should identify leaf taxons" do
    assert @grandchild_taxon.leaf?
    assert_not @child_taxon.leaf?
    assert_not @root_taxon.leaf?
  end

  test "should find ancestors" do
    ancestors = @grandchild_taxon.ancestors
    assert_equal [ @child_taxon, @root_taxon ], ancestors
  end

  test "should find self and ancestors" do
    self_and_ancestors = @grandchild_taxon.self_and_ancestors
    assert_equal [ @grandchild_taxon, @child_taxon, @root_taxon ], self_and_ancestors
  end

  test "should find descendants" do
    descendants = @root_taxon.descendants
    assert_equal [ @child_taxon, @grandchild_taxon ], descendants
  end

  test "should find self and descendants" do
    self_and_descendants = @root_taxon.self_and_descendants
    assert_equal [ @root_taxon, @child_taxon, @grandchild_taxon ], self_and_descendants
  end

  test "should calculate depth" do
    assert_equal 0, @root_taxon.depth
    assert_equal 1, @child_taxon.depth
    assert_equal 2, @grandchild_taxon.depth
  end

  test "should generate full path" do
    assert_equal "Test Taxonomy", @root_taxon.full_path
    assert_equal "Test Taxonomy > Child Taxon", @child_taxon.full_path
    assert_equal "Test Taxonomy > Child Taxon > Grandchild Taxon", @grandchild_taxon.full_path
  end

  test "should scope root taxons" do
    root_taxons = Taxon.roots
    assert_includes root_taxons, @root_taxon
    assert_not_includes root_taxons, @child_taxon
  end

  test "should scope child taxons" do
    child_taxons = Taxon.children
    assert_includes child_taxons, @child_taxon
    assert_includes child_taxons, @grandchild_taxon
    assert_not_includes child_taxons, @root_taxon
  end

  test "should destroy children when parent is destroyed" do
    assert_difference "Taxon.count", -2 do
      @child_taxon.destroy
    end
    assert_not Taxon.exists?(@grandchild_taxon.id)
  end

  test "should allow nil parent for root taxons" do
    new_root = @taxonomy.taxons.create!(name: "New Root", parent: nil)
    assert new_root.valid?
    assert new_root.root?
  end
end
