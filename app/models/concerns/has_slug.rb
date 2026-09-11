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
      string = string.gsub(/_+/, '-')
      string.presence
    end

    def slugify(string)
      self.class.slugify(string)
    end
  end


  private

  def set_slug
    if slug.present?
      self.slug = slugify(slug)
    elsif name_changed?
      self.slug = slugify(name)
    elsif name.present?
      self.slug = slugify(name)
    else
      self.slug = SecureRandom.hex(4)
    end
  end
end