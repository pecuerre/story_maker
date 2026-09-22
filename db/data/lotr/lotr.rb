user = User.create(name: "LOTR User", email_address: "lotr@lotr", password: "lotr", password_confirmation: "lotr")

universe = Universe.create(name: "lotr", owner: user, slug: "lotr", private: false)

story = Story.create(universe: universe, name: "The Lord of the Rings")

st_book = SectionTag.create(universe: universe, name: "Book", parent: nil)
st_part = SectionTag.create(universe: universe, name: "Part", parent: nil)
st_chapter = SectionTag.create(universe: universe, name: "Chapter", parent: nil)
st_section = SectionTag.create(universe: universe, name: "Section", parent: nil)

s_b1 = Section.create(story: story, name: "The Fellowship of the Ring", section_tags: [ st_book ], parent: nil)
s_b2 = Section.create(story: story, name: "The Two Towers", section_tags: [ st_book ], parent: nil)
s_b3 = Section.create(story: story, name: "The Return of the King", section_tags: [ st_book ], parent: nil)
