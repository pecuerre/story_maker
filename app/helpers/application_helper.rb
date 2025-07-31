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
end
