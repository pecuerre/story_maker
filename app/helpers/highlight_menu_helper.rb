module HighlightMenuHelper
  # Generates a border for the element that just was edited or created
  def highlighted_border(item)
    if params[:highlight] == item.id.to_s
      "border border-2 border-primary"
    else
      ""
    end
  end

  def highlight_section(section)
    controller = params[:controller]
    controllers_in_section = controllers_in_section(section)

    # first the fixed controllers
    if controllers_in_section.include?(controller)
      return "bg-primary text-white"
    end

    # then the taxonomies
    return "" unless params[:controller] == "taxons"
    return "" unless params[:action] == "index"
    taxonomies_in_section = taxonomies_in_section(section)
    if taxonomies_in_section.include?(params[:taxonomy_slug])
      return "bg-primary text-white"
    end

    ""
  end

  def highlight_item(param)
    # first check the fixed controllers
    if params[:controller] == param.to_s
      return "bg-primary-subtle text-white"
    end

    # then check the taxonomies
    return "" unless params[:controller] == "taxons"
    return "" unless params[:action] == "index"
    if params[:taxonomy_slug] == param.to_s
      return "bg-primary-subtle text-white"
    end

    ""
  end

  # returns the taxonomies that are in the section
  # this is used to highlight the section in the sidebar
  def taxonomies_in_section(section)
    case section
    when :elements
      Taxonomy::FIXED_TAXONOMIES.select do |taxonomy|
        taxonomy[:story_taxonomy]
      end.map { |taxonomy| taxonomy[:slug] }
    when :settings
      Taxonomy::FIXED_TAXONOMIES.select do |taxonomy|
        taxonomy[:setting_taxonomy]
      end.map { |taxonomy| taxonomy[:slug] }
    else
      []
    end
  end

  # returns the controllers that are in the section
  # this is used to highlight the section in the sidebar
  def controllers_in_section(section)
    case section
    when :elements
      [ "locations" ]
    when :settings
      [ "location_types" ]
    when :general
      []
    else
      []
    end
  end
end
