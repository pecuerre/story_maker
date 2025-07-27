module ApplicationHelper
  # Generates a header with an optional icon based on the provided options.
  def header(title, options = {})
    case options[:icon]
    when :new
      icon = "bi bi-plus-circle"
    when :edit
      icon = "bi bi-pencil-square"
    when :details
      icon = "bi bi-eye"
    when :list
      icon = "bi bi-list-ul"
    end
    title_text = ("<i class='#{icon}'></i> " + title).html_safe
    content_tag(:h3, title_text, class: "mb-4")
  end

  # Generates a border for the element that just was edited or created
  def highlighted_border(item)
    if params[:highlight] == item.id.to_s
      "border border-2 border-primary"
    else
      ""
    end
  end

  def highlighted_sidebar_section(section)
    controller = params[:controller]
    controllers_in_section = controllers_in_section(section)

    if controllers_in_section.include?(controller)
      "bg-primary text-white"
    else
      ""
    end
  end

  def highlighted_sidebar_item(controller)
    if params[:controller] == controller.to_s
      "bg-primary-subtle text-white"
    else
      ""
    end
  end

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
