# Finds the registered Character names and aliases written inside prose.
#
# This is a read-time index, not a stored table: a mention is a fact the prose
# already contains, and a second copy that could disagree with an edited Element
# would be worse than scanning the body when a page asks. It answers one
# question only — *which Character was named at this offset?* — so the caller
# decides whether that mention is a suggestion, a highlight, or part of a grid.
#
# A **mention is never an appearance**. Presence is an explicit `SceneCharacter`
# link or a Dialogue speaker, and this class deliberately knows nothing about
# either. `StoryMentions` joins the two reads when a page wants to say that a
# name is written in a Scene where the Character is not recorded.
#
# The matching rules are part of the contract:
#
# - a Character's `name` and every comma- or newline-separated alias is a
#   candidate spelling;
# - matching is case-insensitive but otherwise exact, so the author's accents
#   and punctuation still decide what is a name;
# - a candidate matches only at a word boundary, so `Ann` does not match
#   `Anna` and `Jon` does not match `Jonas`;
# - the longest candidate at a position wins, so an alias that begins with the
#   bare name is still one mention;
# - a spelling shared by two Characters is **ambiguous** and is left out rather
#   than attributed to whichever row the query returned first.
class MentionIndex
  # One name occurrence in a body. `text` is the spelling as the author wrote
  # it, not the Character's canonical name, and the offsets address the body the
  # index scanned.
  Match = Struct.new(:character, :text, :offset, :length, keyword_init: true)

  # A name is bounded by anything that is not a letter or a number, so quotes,
  # apostrophes, and hyphens stay inside the surrounding sentence rather than
  # becoming part of the name.
  BOUNDARY_BEFORE = '(?<![\p{L}\p{N}])'.freeze
  BOUNDARY_AFTER = '(?![\p{L}\p{N}])'.freeze

  EMPTY = [].freeze

  attr_reader :characters

  # The index for one Story is built from its own Universe's Characters: a
  # Story never sees another Universe's names, and a soft-deleted Character is
  # absent because the ordinary scope already hides it.
  def self.for(story)
    new(story.universe.characters.reorder(:name, :id).to_a)
  end

  def initialize(characters)
    @characters = Array(characters)
    grouped = group_candidates
    @characters_by_key = unambiguous_characters(grouped)
    @pattern = build_pattern(grouped, @characters_by_key)
  end

  # Every match in the body, in reading order. An empty body asks for no work at
  # all.
  def matches(body)
    return EMPTY if body.blank? || @pattern.nil?

    body.to_enum(:scan, @pattern).filter_map do
      match = Regexp.last_match
      text = match[0]
      character = @characters_by_key[normalize(text)]
      next if character.nil?

      Match.new(
        character: character,
        text: text,
        offset: match.begin(0),
        length: text.length
      )
    end
  end

  private
    # normalized spelling => [[spelling, character], ...]. The list keeps every
    # author-written variant because the first one is the alternative the regex
    # uses, while the Character is what the match resolves to.
    def group_candidates
      grouped = Hash.new { |hash, key| hash[key] = [] }

      characters.each do |character|
        candidate_names(character).each do |spelling|
          grouped[normalize(spelling)] << [ spelling, character ]
        end
      end

      grouped
    end

    # A candidate used by exactly one Character is a fact. One used by two is a
    # question the prose cannot answer, so it is not offered as a suggestion.
    # The same Character repeating its own name as an alias is still one owner.
    def unambiguous_characters(grouped)
      grouped.each_with_object({}) do |(key, pairs), characters_by_key|
        owners = pairs.map(&:last).uniq(&:id)
        characters_by_key[key] = owners.first if owners.one?
      end
    end

    def build_pattern(grouped, characters_by_key)
      spellings = characters_by_key.keys.map { |key| grouped[key].first.first }
      return nil if spellings.empty?

      alternatives = spellings
        .uniq
        .sort_by { |spelling| [ -spelling.length, spelling ] }
        .map { |spelling| Regexp.escape(spelling) }
        .join("|")

      Regexp.new("#{BOUNDARY_BEFORE}(?:#{alternatives})#{BOUNDARY_AFTER}", Regexp::IGNORECASE)
    end

    def candidate_names(character)
      listed = character.aliases.to_s.split(/[,\n]/).filter_map { |name| name.strip.presence }

      [ character.name, *listed ].filter_map { |name| name.to_s.strip.presence }.uniq
    end

    # `:nfkc` folds composed and decomposed accents to one shape before the
    # case fold, so a body and an alias written by different input methods still
    # share a key. The regex is case-insensitive; this hash is how its match
    # becomes the Character.
    def normalize(spelling)
      spelling.to_s.unicode_normalize(:nfkc).downcase
    end
end
