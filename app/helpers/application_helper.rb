module ApplicationHelper
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
    title_text = (title + " <i class='#{icon}'></i>").html_safe
    content_tag(:h2, title_text, class: "mb-4")
  end
end
