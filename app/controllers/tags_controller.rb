class TagsController < ApplicationController
  allow_unauthenticated_access only: :index

  def index
    @tag_scope = params[:scope].to_s == "story" ? "story" : "universe"
    allowed_types = @tag_scope == "story" ? %w[section scene] : %w[character relation location event item ownership]
    @tag_type = params[:taxonomy].to_s
    @tag_type = allowed_types.include?(@tag_type) ? @tag_type : allowed_types.first
  end
end
