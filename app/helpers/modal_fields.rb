module ModalFields
  def character_fields(character)
    {
      name: character.name,
      description: character.description,
      character_type_id: character.character_type_id
    }.to_json
  end
end