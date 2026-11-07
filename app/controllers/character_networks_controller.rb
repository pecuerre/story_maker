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
    # Both layers are on by default. The URL records only the decision to turn
    # one off, and the buttons preserve each other.
    @show_unconnected = params[:show_unconnected] != "0"
    @show_faction_links = params[:faction_links] != "0"
    # The server always builds the whole graph, because the client-side toggles
    # only hide layers and must not move a node. The initial URL state is applied
    # as visibility here, so the page is correct before JavaScript runs.
    @network = CharacterNetwork.new(
      Current.universe,
      include_unconnected: true,
      include_faction_links: true
    )
    @layout = CharacterNetworkLayout.new(@network)
  end
end
