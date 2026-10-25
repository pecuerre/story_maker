# Narrows the universe's Faction Tag tree without changing its sibling order.
class FactionTagFilter < ListFilter
  PARAMS = %i[ q ].freeze

  def query_params
    text.present? ? { q: text } : {}
  end

  def apply(relation)
    narrowed_by_text(relation, table: "faction_tags", columns: %w[ name description ])
  end

  private
    def resolve
      resolve_text
    end
end
