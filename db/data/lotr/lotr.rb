user = User.create(name: "LOTR User", email_address: "lotr@lotr", password: "lotr", password_confirmation: "lotr")

story = Story.create(name: "lotr", owner: user, slug: "lotr", private: false)

st_book = SectionType.create(story: story, name: "Book", parent: nil)
st_part = SectionType.create(story: story, name: "Part", parent: nil)
st_chapter = SectionType.create(story: story, name: "Chapter", parent: nil)
st_section = SectionType.create(story: story, name: "Section", parent: nil)

s_b1 = Section.create(story: story, name: "The Fellowship of the Ring", section_types: [ st_book ], parent: nil)
s_b2 = Section.create(story: story, name: "The Two Towers", section_types: [ st_book ], parent: nil)
s_b3 = Section.create(story: story, name: "The Return of the King", section_types: [ st_book ], parent: nil)