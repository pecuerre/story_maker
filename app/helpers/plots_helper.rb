module PlotsHelper
  # The values the Plot modal prefills for an edit. The shared modal contract
  # sends them back to the same editor, so the list row and the details-page Edit
  # control open one form rather than two.
  def plot_fields_json(plot)
    { name: plot.name, short_summary: plot.short_summary, description: plot.description }.to_json
  end

  # The one-line summary as safe inline HTML for the details page: a reference
  # becomes the link it is inside the record's own description. The short summary
  # is not Markdown, so no heading, emphasis, or table is interpreted there.
  def plot_summary_html(plot)
    MarkdownDescription.new(Current.universe, plot.short_summary).to_inline_html
  end

  # The same summary as plain text for a list row: a reference is reduced to the
  # name of the record it names and never becomes a link, because the row already
  # carries its own Details link. The value is plain text, so the view escapes it
  # like any other string.
  def plot_summary_text(plot)
    MarkdownDescription.new(Current.universe, plot.short_summary).as_plain_text
  end
end
