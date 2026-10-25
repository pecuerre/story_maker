# frozen_string_literal: true

class Ability
  include CanCan::Ability

  # The policy is object-based: callers pass the concrete universe or content
  # record so private membership and owner checks are evaluated against the
  # correct scope. The custom :write and :admin actions represent the two
  # collaboration levels used by the request authorization concern.
  #
  # A class-level check is the one question this policy cannot answer from a
  # record, so it is given an answer of its own rather than left to CanCan, which
  # answers a block rule with `true` for the class the rule was declared on —
  # allowed without any universe ever being consulted. The answer is narrow on
  # purpose: **does this user hold this action on at least one record of this
  # class inside the universe the request has already authorized?**
  #
  # The universe arrives through the constructor rather than being read from
  # `Current` here, so the ability stays a policy object and the scope stays the
  # one the request really authorized. Outside such a universe there is nowhere to
  # look, and the answer is `false`.
  #
  # Each rule below is declared once and yields both answers, and each half of a
  # class check is the question the instance block asks of a record: the
  # universe's access level for this user, and the model's path to its universe.
  # That is what keeps the two from answering differently about the same user and
  # the same row.

  CONTENT_CLASS_NAMES = %w[
    Story
    Section
    SectionTag
    Scene
    Plot
    SceneTag
    SceneElement
    SceneDialogueTurn
    SceneCharacter
    SceneItem
    SceneLocation
    Character
    CharacterKnowledge
    CharacterTag
    Faction
    FactionTag
    FactionRelationship
    Location
    LocationTag
    Route
    Item
    ItemTag
    Event
    EventTag
    Relation
    RelationTag
    Ownership
    OwnershipTag
    Photo
  ].freeze

  # A Photo has no route and no page of its own: it is written only through the
  # form of the record that shows it, which is already authorized. It is listed
  # here so a generic `authorize!` on the class is never allowed for lack of a
  # rule, and because `UniverseScopeResolver` answers for it.

  def initialize(user, universe = nil)
    @user = user
    @universe = universe
    @class_rules = []

    define_universe_abilities
    define_content_abilities
    define_membership_abilities
    define_platform_abilities
  end

  def access_level_for(universe)
    universe&.access_level_for(@user)
  end

  # A class-level check never reaches CanCan's instance rules: a block matched
  # against a class returns `true` without the block ever running. A subject this
  # ability declares a class rule for is answered from the database instead, and
  # everything else falls through — `can :create, Universe`, and every class with
  # no rule at all, which CanCan refuses as an unauthorized action because no rule
  # matches it.
  def can?(action, subject, attribute = nil, *extra_args)
    answers = (subject.is_a?(Array) ? subject : [ subject ]).map { |one| class_answer(action, one) }

    return super if answers.include?(nil)

    answers.all?
  end

  private

    def define_universe_abilities
      define_rule(Universe, :read, %i[read index show]) { |universe| universe }

      if @user
        define_rule(Universe, :write, %i[write new]) { |universe| universe }
        # The one check CanCan is left to answer. There is no record yet and no
        # universe to scope it to: creating one is a question about the person
        # rather than about a place they have been given.
        can :create, Universe
        define_rule(Universe, :admin, %i[admin edit update destroy manage]) { |universe| universe }
      end
    end

    def define_content_abilities
      CONTENT_CLASS_NAMES.each do |class_name|
        content_class = class_name.constantize

        define_rule(content_class, :read, %i[read index show])

        next unless @user

        define_rule(content_class, :write, %i[write new create update destroy])
        define_rule(content_class, :admin, %i[admin manage])
      end
    end

    def define_membership_abilities
      return unless @user

      # A membership is readable by whoever may administer the universe, not by
      # whoever may read it, so both halves of this rule are the admin level — the
      # same answer the record rule gives.
      define_rule(UniverseMembership, :admin, %i[read index show])
      define_rule(UniverseMembership, :admin, %i[admin manage create update destroy])
    end

  # One rule, two answers. The CanCan block asks the access-level question of
  # the record's universe; the entry recorded alongside it asks the same question
  # of the request's universe, and `can?` answers that one from the database.
  # Declaring them together is what keeps a class check and a record check from
  # answering differently about the same user and the same universe.
  #
  # `universe_of` is how a model's universe is reached. It is a block because
  # `universe_for` walks the owner associations, which is right for content and
  # wrong for a `Universe`, whose universe is the record itself.
  # **The one privilege that is not about a universe.** Every other rule above is a
  # level inside one: the universe's access level for this user, evaluated against
  # the scope the request already authorized. `PlatformSetting` has no universe —
  # it holds the universe-*creation* limit, which is read before there is a universe
  # to read it from — so it is asked a different question: is this account an
  # operator of the platform itself?
  #
  # That answer is `users.platform_admin`, an operator flag nothing in the interface
  # sets, and it is deliberately not a universe level. There is no universe whose
  # admins could own it, so borrowing `admin` here would say that anyone who
  # administers any universe configures the platform.
  #
  # It is declared as a class rule rather than a CanCan `can` block for the same
  # reason the others are: a block matched against a class returns `true` without the
  # block running, which would hand the privilege to everyone. `class_answer` asks
  # the database instead.
  def define_platform_abilities
    return unless @user&.platform_admin?

    @class_rules << { model: PlatformSetting, action: :manage, level: :platform }
  end

  def define_rule(model, level, actions, &universe_of)
      universe_of ||= ->(record) { universe_for(record) }

      actions.each do |action|
        can action, model do |record|
          universe_permits?(universe_of.call(record), level)
        end

        @class_rules << { model: model, action: action, level: level }
      end
    end

    # The three access levels, named once. Both answers to both kinds of check go
    # through here, so a level cannot mean one thing to a record and another to a
    # class.
    def universe_permits?(universe, level)
      # The one level that is not a question about a universe, asked before the
      # nil guard below: there is no universe to consult, so a nil scope is the
      # normal case for it rather than a refusal.
      return @user.present? && @user.platform_admin? if level == :platform

      return false if universe.nil?

      case level
      when :read then universe.readable_by?(@user)
      when :write then universe.writable_by?(@user)
      when :admin then universe.administrable_by?(@user)
      end
    end

    # nil when CanCan is the right answer, because this ability declares no class
    # rule for that subject.
    def class_answer(action, subject)
      return unless subject.is_a?(Class)

      rule = @class_rules.find { |declared| declared[:model] == subject && declared[:action] == action.to_sym }
      return unless rule
      return false unless universe_permits?(@universe, rule[:level])

      # The authorized universe *is* the `Universe` record, so for that one class
      # the record always exists once the level above has been answered. A
      # `PlatformSetting` is the other case of the same shape: it is not *inside* an
      # authorized universe, so there is nothing to look for rows of — and routing it
      # through `UniverseScopeResolver` would ask a resolver that has no rule for it.
      return true if [ Universe, PlatformSetting ].include?(subject)

      UniverseScopeResolver.records_in(subject, @universe).exists?
    end

    def universe_for(record)
      UniverseScopeResolver.universe_for(record)
    end
end
