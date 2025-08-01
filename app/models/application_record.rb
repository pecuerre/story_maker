class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Common functionality for all models can be added here
  def to_slug(string)
    # string.downcase.gsub(/\s+/, "-").gsub(/[^a-z0-9-]/, "")
    string.parameterize
  end

  def set_slug
    self.slug ||= to_slug(name)
  end
end
