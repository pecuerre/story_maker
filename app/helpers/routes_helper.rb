module RoutesHelper
  def route_fields_json(route)
    {
      name: route.name,
      from_location_id: route.from_location_id,
      to_location_id: route.to_location_id,
      distance: route.distance,
      duration: route.duration,
      description: route.description,
      photo_url: record_photo_url(route)
    }.to_json
  end
end
