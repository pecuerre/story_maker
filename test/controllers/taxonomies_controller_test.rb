require "test_helper"

class TaxonomiesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @taxonomy = Taxonomy.create!(
      name: "Test Taxonomy",
      description: "A test taxonomy",
      slug: "test-taxonomy",
      fixed: false
    )
  end

  test "should get index" do
    get taxonomies_url
    assert_response :success
    assert_not_nil assigns(:taxonomies)
  end

  test "should get new" do
    get new_taxonomy_url
    assert_response :success
    assert_not_nil assigns(:taxonomy)
  end

  test "should create taxonomy" do
    assert_difference("Taxonomy.count") do
      post taxonomies_url, params: {
        taxonomy: {
          name: "New Taxonomy",
          description: "A new taxonomy",
          slug: "new-taxonomy",
          fixed: false
        }
      }
    end

    assert_redirected_to taxonomy_url(Taxonomy.last)
    assert_equal "Taxonomy was successfully created.", flash[:notice]
  end

  test "should not create taxonomy with invalid params" do
    assert_no_difference("Taxonomy.count") do
      post taxonomies_url, params: {
        taxonomy: {
          name: "",
          slug: "invalid slug"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should show taxonomy" do
    get taxonomy_url(@taxonomy)
    assert_response :success
    assert_equal @taxonomy, assigns(:taxonomy)
  end

  test "should get edit" do
    get edit_taxonomy_url(@taxonomy)
    assert_response :success
    assert_equal @taxonomy, assigns(:taxonomy)
  end

  test "should update taxonomy" do
    patch taxonomy_url(@taxonomy), params: {
      taxonomy: {
        name: "Updated Taxonomy",
        description: "Updated description"
      }
    }

    assert_redirected_to taxonomy_url(@taxonomy)
    assert_equal "Taxonomy was successfully updated.", flash[:notice]
    @taxonomy.reload
    assert_equal "Updated Taxonomy", @taxonomy.name
  end

  test "should not update taxonomy with invalid params" do
    patch taxonomy_url(@taxonomy), params: {
      taxonomy: {
        name: "",
        slug: "invalid slug"
      }
    }

    assert_response :unprocessable_entity
  end

  test "should destroy taxonomy" do
    assert_difference("Taxonomy.count", -1) do
      delete taxonomy_url(@taxonomy)
    end

    assert_redirected_to taxonomies_url
    assert_equal "Taxonomy was successfully deleted.", flash[:notice]
  end

  test "should not destroy fixed taxonomy" do
    @taxonomy.update!(fixed: true)

    assert_no_difference("Taxonomy.count") do
      delete taxonomy_url(@taxonomy)
    end

    assert_redirected_to taxonomy_url(@taxonomy)
    assert_equal "Cannot delete a fixed taxonomy.", flash[:alert]
  end

  test "should respond to json" do
    get taxonomy_url(@taxonomy), as: :json
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal @taxonomy.id, response_data["id"]
    assert_equal @taxonomy.name, response_data["name"]
  end
end
