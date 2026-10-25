module FactionRelationshipsHelper
  def faction_relationship_fields_json(relationship)
    {
      name: relationship.name,
      from_faction_id: relationship.from_faction_id,
      to_faction_id: relationship.to_faction_id,
      description: relationship.description,
      from_date: datetime_local_value(relationship.from_date),
      to_date: datetime_local_value(relationship.to_date),
      photo_url: record_photo_url(relationship)
    }.to_json
  end
end
