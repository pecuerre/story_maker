class SectionType < ApplicationRecord
  belongs_to :story
  belongs_to :parent, class_name: "SectionType", optional: true
end
