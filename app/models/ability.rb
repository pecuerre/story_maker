# frozen_string_literal: true

class Ability
  include CanCan::Ability

  # The policy is object-based: callers pass the concrete universe or content
  # record so private membership and owner checks are evaluated against the
  # correct scope. The custom :write and :admin actions represent the two
  # collaboration levels used by the request authorization concern.

  CONTENT_CLASS_NAMES = %w[
    Story
    Section
    SectionTag
    Scene
    SceneTag
    Character
    CharacterTag
    Location
    LocationTag
    Item
    ItemTag
    Event
    EventTag
    Relation
    RelationTag
    Ownership
    OwnershipTag
  ].freeze

  def initialize(user)
    @user = user

    define_universe_abilities
    define_content_abilities
    define_membership_abilities
  end

  def access_level_for(universe)
    universe&.access_level_for(@user)
  end

  private

    def define_universe_abilities
      can [ :read, :index, :show ], Universe do |universe|
        universe.present? && universe.readable_by?(@user)
      end

      if @user
        can [ :write, :new ], Universe do |universe|
          universe.present? && universe.writable_by?(@user)
        end
        can :create, Universe
        can [ :admin, :edit, :update, :destroy, :manage ], Universe do |universe|
          universe.present? && universe.administrable_by?(@user)
        end
      end
    end

    def define_content_abilities
      CONTENT_CLASS_NAMES.each do |class_name|
        content_class = class_name.constantize

        can [ :read, :index, :show ], content_class do |record|
          universe = universe_for(record)
          universe.present? && universe.readable_by?(@user)
        end

        next unless @user

        can [ :write, :new, :create, :update, :destroy ], content_class do |record|
          universe = universe_for(record)
          universe.present? && universe.writable_by?(@user)
        end
        can :admin, content_class do |record|
          universe = universe_for(record)
          universe.present? && universe.administrable_by?(@user)
        end
        can :manage, content_class do |record|
          universe = universe_for(record)
          universe.present? && universe.administrable_by?(@user)
        end
      end
    end

    def define_membership_abilities
      return unless @user

      can [ :read, :index, :show ], UniverseMembership do |membership|
        membership.present? && membership.universe.administrable_by?(@user)
      end
      can [ :admin, :manage, :create, :update, :destroy ], UniverseMembership do |membership|
        membership.present? && membership.universe.administrable_by?(@user)
      end
    end

    def universe_for(record)
      UniverseScopeResolver.universe_for(record)
    end
end
