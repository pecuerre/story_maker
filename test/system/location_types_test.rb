require "application_system_test_case"

class LocationTypesTest < ApplicationSystemTestCase
  setup do
    @location_type = location_types(:one)
  end

  test "visiting the index" do
    visit location_types_url
    assert_selector "h1", text: "Location types"
  end

  test "should create location type" do
    visit location_types_url
    click_on "New location type"

    fill_in "Description", with: @location_type.description
    fill_in "Name", with: @location_type.name
    fill_in "Story", with: @location_type.story_id
    click_on "Create Location type"

    assert_text "Location type was successfully created"
    click_on "Back"
  end

  test "should update Location type" do
    visit location_type_url(@location_type)
    click_on "Edit this location type", match: :first

    fill_in "Description", with: @location_type.description
    fill_in "Name", with: @location_type.name
    fill_in "Story", with: @location_type.story_id
    click_on "Update Location type"

    assert_text "Location type was successfully updated"
    click_on "Back"
  end

  test "should destroy Location type" do
    visit location_type_url(@location_type)
    click_on "Destroy this location type", match: :first

    assert_text "Location type was successfully destroyed"
  end
end
