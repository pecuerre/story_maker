# The universes an API token may reach. A token narrows a request to these rows;
# anything else is a refusal.
class ApiTokenUniverse < ApplicationRecord
  belongs_to :api_token
  belongs_to :universe
end
