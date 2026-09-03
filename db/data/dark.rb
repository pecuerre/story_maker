user = User.create(email_address: "dark@dark", password: "dark", password_confirmation: "dark")

story = Story.create(name: "Dark", owner: user, slug: "dark", private: false)

st_season = SectionType.create(story: story, name: "Season", parent: nil)
st_episode = SectionType.create(story: story, name: "Episode", parent: nil)

s_s1 = Section.create(story: story, name: "Season 1", section_type: st_season, parent: nil)
s_s1e1 = Section.create(story: story, name: "Episode 1: Secrets", section_type: st_episode, parent: s_s1)
s_s1e2 = Section.create(story: story, name: "Episode 2: Lies", section_type: st_episode, parent: s_s1)
s_s1e3 = Section.create(story: story, name: "Episode 3: Past and Present", section_type: st_episode, parent: s_s1)
s_s1e4 = Section.create(story: story, name: "Episode 4: Double Lives", section_type: st_episode, parent: s_s1)
s_s1e5 = Section.create(story: story, name: "Episode 5: Truths", section_type: st_episode, parent: s_s1)
s_s1e6 = Section.create(story: story, name: "Episode 6: Sic Mundus Creatus Est", section_type: st_episode, parent: s_s1)

s_s2 = Section.create(story: story, name: "Season 2", section_type: st_season, parent: nil)
s_s2e1 = Section.create(story: story, name: "Episode 1", section_type: st_episode, parent: s_s2)
s_s2e2 = Section.create(story: story, name: "Episode 2", section_type: st_episode, parent: s_s2)
s_s2e3 = Section.create(story: story, name: "Episode 3", section_type: st_episode, parent: s_s2)

s_s3 = Section.create(story: story, name: "Season 3", section_type: st_season, parent: nil)
s_s3e1 = Section.create(story: story, name: "Episode 1", section_type: st_episode, parent: s_s3)
s_s3e2 = Section.create(story: story, name: "Episode 2", section_type: st_episode, parent: s_s3)
s_s3e3 = Section.create(story: story, name: "Episode 3", section_type: st_episode, parent: s_s3)