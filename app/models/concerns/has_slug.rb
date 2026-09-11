module HasSlug
  extend ActiveSupport::Concern

  included do
    before_validation :set_slug
  end

  private

  def set_slug
    if name_changed?
      self.slug = name.to_s.parameterize.presence
    elsif name.present?
      self.slug = name.to_s.parameterize.presence
    else
      self.slug = SecureRandom.hex(4)
    end
  end
end