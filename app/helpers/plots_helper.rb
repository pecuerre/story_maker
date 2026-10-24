module PlotsHelper
  def plot_fields_json(plot)
    { name: plot.name, description: plot.description }.to_json
  end
end
