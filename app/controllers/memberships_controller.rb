class MembershipsController < ApplicationController
  before_action :set_membership, only: %i[ update destroy ]

  def index
    @membership = Current.universe.memberships.build(access_level: :read)
    load_memberships
  end

  def new
    @membership = Current.universe.memberships.build(access_level: :read)
    load_memberships
  end

  def create
    attributes = create_membership_params
    @membership = Current.universe.memberships.build
    assign_access_level(attributes[:access_level])

    user = User.find_by(email_address: attributes[:email_address].to_s.strip.downcase)
    if user.nil?
      @membership.errors.add(:email_address, t("memberships.errors.email_not_found"))
    elsif user == Current.universe.owner
      @membership.errors.add(:email_address, t("memberships.errors.is_universe_owner"))
    else
      @membership.user = user
    end

    if @membership.errors.empty? && @membership.save
      redirect_to universe_memberships_path(universe_slug: Current.universe.slug),
        notice: t("memberships.flash.granted"), status: :see_other
    else
      load_memberships
      render :index, status: :unprocessable_content
    end
  end

  def update
    if own_membership?
      redirect_to root_path, alert: t("memberships.flash.own_change_refused"), status: :see_other
      return
    end

    attributes = update_membership_params
    assign_access_level(attributes[:access_level])

    if @membership.errors.empty? && @membership.update(access_level: @membership.access_level)
      redirect_to universe_memberships_path(universe_slug: Current.universe.slug),
        notice: t("memberships.flash.updated"), status: :see_other
    else
      load_memberships
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    if own_membership?
      redirect_to root_path, alert: t("memberships.flash.own_removal_refused"), status: :see_other
      return
    end

    @membership.soft_delete
    redirect_to universe_memberships_path(universe_slug: Current.universe.slug),
      notice: t("memberships.flash.removed"), status: :see_other
  end

  private

    def set_membership
      @membership = Current.universe.memberships.find(params.expect(:id))
    end

    def own_membership?
      @membership.user == Current.user
    end

    # `references` keeps the join the name ordering needs, and it is what makes
    # `includes` load the users with the memberships instead of leaving the view
    # to fetch one per row: every row prints a name, an address, and an aria
    # label.
    def load_memberships
      @memberships = Current.universe.memberships
        .includes(:user).references(:user)
        .order("LOWER(users.name)").to_a
    end

    def create_membership_params
      params.expect(membership: [ :email_address, :access_level ])
    end

    def update_membership_params
      params.expect(membership: [ :access_level ])
    end

    def assign_access_level(value)
      level = value.to_s
      if UniverseMembership::ACCESS_LEVELS.key?(level.to_sym)
        @membership.access_level = level
      else
        @membership.errors.add(:access_level, t("memberships.errors.invalid_access_level"))
      end
    end
end
