class CharacterNetworksController < ApplicationController
  allow_unauthenticated_access only: :show

  # GET /u/:universe_slug/network
  #
  # The Characters workspace's read-only Network tab. The network is derived from
  # the Universe's live Stories, Scenes, and Dialogue on every request; the layout
  # is derived from that result, so neither the graph nor the coordinates are
  # stored. Access is the same read the Characters list grants.
  def show
    # The toggle is a view option, not a filter: it changes which nodes are
    # drawn and never which records exist. Only the one documented value turns it
    # on, so a hand-edited URL cannot ask for an arbitrary mode.
    # Both view layers are on by default. The URL records only the decision to
    # turn one off, and the toggles preserve each other.
    show_unconnected = params[:show_unconnected] != "0"
    # Faction links are on by default, so the URL records only the decision to
    # turn them off. The label on the toggle stays the same and `aria-pressed`
    # states which way it is set.
    include_faction_links = params[:faction_links] != "0"
    @network = CharacterNetwork.new(
      Current.universe,
      include_unconnected: show_unconnected,
      include_faction_links: include_faction_links
    )
    @layout = CharacterNetworkLayout.new(@network)
  end
end
