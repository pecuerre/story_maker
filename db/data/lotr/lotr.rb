user = User.create(name: "LOTR User", email_address: "lotr@lotr", password: "lotr", password_confirmation: "lotr")

universe = Universe.create(name: "lotr", owner: user, slug: "lotr", private: false)

st_book = SectionType.create(universe: universe, name: "Book", parent: nil)
st_part = SectionType.create(universe: universe, name: "Part", parent: nil)
st_chapter = SectionType.create(universe: universe, name: "Chapter", parent: nil)
st_section = SectionType.create(universe: universe, name: "Section", parent: nil)

s_b1 = Section.create(universe: universe, name: "The Fellowship of the Ring", section_types: [ st_book ], parent: nil)
s_b2 = Section.create(universe: universe, name: "The Two Towers", section_types: [ st_book ], parent: nil)
s_b3 = Section.create(universe: universe, name: "The Return of the King", section_types: [ st_book ], parent: nil)