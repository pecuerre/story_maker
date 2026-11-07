# Paths for the Network tab's two view options. Each toggle keeps the other
# option exactly as the reader left it, so turning one on or off never silently
# resets the other.
module CharacterNetworksHelper
  # Both options are on by default, so the URL records the exception: `0` turns
  # one off and its absence turns it back on. The booleans are the *rendered*
  # view state, not the network's data flags: the network always holds the whole
  # graph so a toggle cannot move a node.
  def character_network_unconnected_toggle_path(show_unconnected:, show_faction_links:)
    params = {}
    params[:show_unconnected] = "0" if show_unconnected
    params[:faction_links] = "0" unless show_faction_links
    universe_character_network_path(**params)
  end

  def character_network_faction_links_toggle_path(show_unconnected:, show_faction_links:)
    params = {}
    params[:show_unconnected] = "0" unless show_unconnected
    params[:faction_links] = "0" if show_faction_links
    universe_character_network_path(**params)
  end
end
