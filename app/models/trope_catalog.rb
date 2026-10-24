# A small, curated reference set. The descriptions and craft notes are original
# Universe Maker copy; source links point readers to the cited discussion.
class TropeCatalog
  Entry = Data.define(:slug, :name, :description_key, :craft_note_key, :source_url)

  SOURCE_NAME = "TV Tropes"
  SOURCE_LICENSE_URL = "https://creativecommons.org/licenses/by-nc-sa/3.0/"

  ENTRIES = [
    Entry.new(slug: "damsel-in-distress", name: "Damsel in Distress", description_key: "tropes.catalog.damsel_in_distress.description", craft_note_key: "tropes.catalog.damsel_in_distress.craft_note", source_url: "https://tvtropes.org/pmwiki/pmwiki.php/Main/DamselInDistress"),
    Entry.new(slug: "women-in-refrigerators", name: "Women in Refrigerators", description_key: "tropes.catalog.women_in_refrigerators.description", craft_note_key: "tropes.catalog.women_in_refrigerators.craft_note", source_url: "https://tvtropes.org/pmwiki/pmwiki.php/Main/WomenInRefrigerators"),
    Entry.new(slug: "magical-negro", name: "Magical Negro", description_key: "tropes.catalog.magical_negro.description", craft_note_key: "tropes.catalog.magical_negro.craft_note", source_url: "https://tvtropes.org/pmwiki/pmwiki.php/Main/MagicalNegro"),
    Entry.new(slug: "manic-pixie-dream-girl", name: "Manic Pixie Dream Girl", description_key: "tropes.catalog.manic_pixie_dream_girl.description", craft_note_key: "tropes.catalog.manic_pixie_dream_girl.craft_note", source_url: "https://tvtropes.org/pmwiki/pmwiki.php/Main/ManicPixieDreamGirl"),
    Entry.new(slug: "bury-your-gays", name: "Bury Your Gays", description_key: "tropes.catalog.bury_your_gays.description", craft_note_key: "tropes.catalog.bury_your_gays.craft_note", source_url: "https://tvtropes.org/pmwiki/pmwiki.php/Main/BuryYourGays"),
    Entry.new(slug: "chekhovs-gun", name: "Chekhov’s Gun", description_key: "tropes.catalog.chekhovs_gun.description", craft_note_key: "tropes.catalog.chekhovs_gun.craft_note", source_url: "https://tvtropes.org/pmwiki/pmwiki.php/Main/ChekhovsGun"),
    Entry.new(slug: "red-herring", name: "Red Herring", description_key: "tropes.catalog.red_herring.description", craft_note_key: "tropes.catalog.red_herring.craft_note", source_url: "https://tvtropes.org/pmwiki/pmwiki.php/Main/RedHerring"),
    Entry.new(slug: "found-family", name: "Found Family", description_key: "tropes.catalog.found_family.description", craft_note_key: "tropes.catalog.found_family.craft_note", source_url: "https://tvtropes.org/pmwiki/pmwiki.php/Main/FoundFamily"),
    Entry.new(slug: "character-foil", name: "Character Foil", description_key: "tropes.catalog.character_foil.description", craft_note_key: "tropes.catalog.character_foil.craft_note", source_url: "https://tvtropes.org/pmwiki/pmwiki.php/Main/Foil"),
    Entry.new(slug: "fish-out-of-water", name: "Fish Out of Water", description_key: "tropes.catalog.fish_out_of_water.description", craft_note_key: "tropes.catalog.fish_out_of_water.craft_note", source_url: "https://tvtropes.org/pmwiki/pmwiki.php/Main/FishOutOfWater")
  ].freeze

  class << self
    def entries
      ENTRIES
    end

    def slugs
      @slugs ||= ENTRIES.map(&:slug).freeze
    end

    def find(slug)
      ENTRIES.find { |entry| entry.slug == slug.to_s }
    end
  end
end
