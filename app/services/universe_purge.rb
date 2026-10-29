# The one operation that removes a universe for good.
#
# `Universe#destroy` through `SoftDeletable` marks rows with `deleted_at`; it
# deliberately keeps every child row so the universe can be restored. This service
# is the other delete: it walks the universe's declared `dependent: :destroy` and
# `dependent: :delete_all` associations and destroys each child, then destroys the
# universe itself in the same transaction.
#
# **The walk exists because Active Record's own cascade cannot see a soft-deleted
# child.** A `has_many ... dependent: :destroy` reads the association through the
# model's default scope, so a story, character, or scene that was soft-deleted
# earlier is invisible to the cascade and would be left behind with a foreign key
# naming a universe that no longer exists. Every child relation here is read
# through `with_deleted` when its model supports it, so a purge takes the hidden
# rows as well.
#
# It follows the associations rather than naming tables, so a new universe-owned
# model arrives in the purge when it arrives in the cascade. The exceptions are
# associations that must not cascade at all — `dependent: :nullify` — and
# HABTM join rows, which Active Record removes when either endpoint is destroyed.
# `Photo` is a child through the universe's own `has_many :photos`.
#
# The whole walk is one transaction. A destroy that raises takes the transaction
# down with it rather than leaving half a universe and a row that still answers to
# its slug. The `after_commit` callbacks on the destroyed records still run after
# the commit, so search removals and menu-count invalidation reach their jobs.
class UniversePurge
  def self.call(universe)
    new(universe).call
  end

  def initialize(universe)
    @universe = universe
  end

  def call
    Universe.transaction do
      purge_dependents(@universe)
      @universe.destroy!
    end
  end

  private
    def purge_dependents(record)
      record.class.reflect_on_all_associations.each do |reflection|
        next unless purgeable?(reflection)

        scope = record.association(reflection.name).scope
        scope = scope.with_deleted if reflection.klass.respond_to?(:with_deleted)

        if reflection.options[:dependent] == :delete_all
          scope.delete_all
        elsif reflection.collection?
          scope.find_each do |child|
            purge_dependents(child)
            child.destroy!
          end
        else
          child = scope.first
          next if child.nil?

          purge_dependents(child)
          child.destroy!
        end
      end
    end

    # `:destroy` cascades undergo the same walk, so a soft-deleted child is
    # reached even when its parent's own callback would skip it. `:delete_all` is
    # a join table with no callbacks of its own. Everything else — `:nullify`, and
    # the associations with no `dependent:` — is deliberately not followed.
    def purgeable?(reflection)
      return false unless %i[has_many has_one].include?(reflection.macro)
      return false if reflection.through_reflection?

      %i[destroy delete_all].include?(reflection.options[:dependent])
    end
end
