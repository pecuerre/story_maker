require "test_helper"

class TaxonsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @taxonomy = Taxonomy.create!(
      name: "Test Taxonomy",
      description: "A test taxonomy",
      slug: "test-taxonomy",
      fixed: false
    )
    @root_taxon = @taxonomy.taxons.first
    @child_taxon = @taxonomy.taxons.create!(name: "Child Taxon", parent: @root_taxon)
  end

  test "should get index" do
    get taxons_url
    assert_response :success
    assert_not_nil assigns(:taxons)
  end

  test "should get index for taxonomy" do
    get taxonomy_taxons_url(@taxonomy)
    assert_response :success
    assert_not_nil assigns(:taxons)
  end

  test "should get new" do
    get new_taxonomy_taxon_url(@taxonomy)
    assert_response :success
    assert_not_nil assigns(:taxon)
    assert_not_nil assigns(:parent_taxons)
  end

  test "should get new for taxonomy" do
    get new_taxonomy_taxon_url(@taxonomy)
    assert_response :success
    assert_not_nil assigns(:taxon)
    assert_not_nil assigns(:parent_taxons)
  end

  test "should create taxon" do
    assert_difference("Taxon.count") do
      post taxonomy_taxons_url(@taxonomy), params: {
        taxon: {
          name: "New Taxon",
          parent_id: @root_taxon.id
        }
      }
    end

    assert_redirected_to taxonomy_url(@taxonomy)
    assert_equal "Taxon was successfully created.", flash[:notice]
  end

  test "should create taxon for taxonomy" do
    assert_difference("Taxon.count") do
      post taxonomy_taxons_url(@taxonomy), params: {
        taxon: {
          name: "New Taxon",
          parent_id: @root_taxon.id
        }
      }
    end

    assert_redirected_to taxonomy_url(@taxonomy)
    assert_equal "Taxon was successfully created.", flash[:notice]
  end

  test "should not create taxon with invalid params" do
    assert_no_difference("Taxon.count") do
      post taxonomy_taxons_url(@taxonomy), params: {
        taxon: {
          name: ""
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_taxonomy_taxon_url(@taxonomy, @child_taxon)
    assert_response :success
    assert_equal @child_taxon, assigns(:taxon)
  end

  test "should get edit for taxonomy" do
    get edit_taxonomy_taxon_url(@taxonomy, @child_taxon)
    assert_response :success
    assert_equal @child_taxon, assigns(:taxon)
  end

  test "should update taxon" do
    patch taxonomy_taxon_url(@taxonomy, @child_taxon), params: {
      taxon: {
        name: "Updated Taxon"
      }
    }

    assert_redirected_to taxonomy_url(@taxonomy)
    assert_equal "Taxon was successfully updated.", flash[:notice]
    @child_taxon.reload
    assert_equal "Updated Taxon", @child_taxon.name
  end

  test "should not update taxon with invalid params" do
    patch taxonomy_taxon_url(@taxonomy, @child_taxon), params: {
      taxon: {
        name: ""
      }
    }

    assert_response :unprocessable_entity
  end

  test "should destroy taxon" do
    assert_difference("Taxon.count", -1) do
      delete taxonomy_taxon_url(@taxonomy, @child_taxon)
    end

    assert_redirected_to taxonomy_url(@taxonomy)
    assert_equal "Taxon was successfully deleted.", flash[:notice]
  end

  test "should not destroy root taxon of fixed taxonomy" do
    @taxonomy.update!(fixed: true)

    assert_no_difference("Taxon.count") do
      delete taxonomy_taxon_url(@taxonomy, @root_taxon)
    end

    assert_redirected_to taxonomy_url(@taxonomy)
    assert_equal "Cannot delete the root taxon of a fixed taxonomy.", flash[:alert]
  end

  test "should respond to json for index" do
    get taxonomy_taxons_url(@taxonomy), as: :json
    assert_response :success
    assert_not_nil JSON.parse(response.body)
  end

  test "should respond to json for create" do
    assert_difference("Taxon.count") do
      post taxonomy_taxons_url(@taxonomy), params: {
        taxon: {
          name: "JSON Taxon",
          parent_id: @root_taxon.id
        }
      }, as: :json
    end

    assert_response :created
    assert_not_nil JSON.parse(response.body)
  end

  test "should respond to json for update" do
    patch taxonomy_taxon_url(@taxonomy, @child_taxon), params: {
      taxon: {
        name: "JSON Updated Taxon"
      }
    }, as: :json

    assert_response :success
    assert_not_nil JSON.parse(response.body)
  end

  test "should respond to json for destroy" do
    assert_difference("Taxon.count", -1) do
      delete taxonomy_taxon_url(@taxonomy, @child_taxon), as: :json
    end

    assert_response :no_content
  end
end
