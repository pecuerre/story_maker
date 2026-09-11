module HasColor
  extend ActiveSupport::Concern

  included do
    validates :color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a hex color like #d3d3d3" }
  end
end
