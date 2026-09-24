module HasSlug
  extend ActiveSupport::Concern

  included do
    before_validation :set_slug

    def self.method_missing(method, *args, &block)
      self.find_by(slug: slugify(method)) || super
    end

    def self.slugify(string)
      string = string.to_s
      string = string.parameterize
      string = string.gsub(/_+/, "-")
      string.presence
    end

    def slugify(string)
      self.class.slugify(string)
    end
  end


  private

  # An explicitly assigned slug wins for this save; otherwise a changed name regenerates it.
  def set_slug
    if will_save_change_to_slug? && slug.present?
      self.slug = normalized_slug(slug)
    elsif will_save_change_to_name?
      self.slug = normalized_slug(name)
    elsif slug.present?
      self.slug = normalized_slug(slug)
    elsif name.present?
      self.slug = normalized_slug(name)
    else
      self.slug = SecureRandom.hex(4)
    end
  end

  def normalized_slug(value)
    slugify(value).presence || SecureRandom.hex(4)
  end
end
