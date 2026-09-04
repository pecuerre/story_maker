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

lt_town = LocationType.create(story: story, name: "Town", parent: nil)
lt_house = LocationType.create(story: story, name: "House", parent: nil)
lt_school = LocationType.create(story: story, name: "School", parent: nil)
lt_police = LocationType.create(story: story, name: "Police", parent: nil)
lt_forest = LocationType.create(story: story, name: "Forest", parent: nil)
lt_cave = LocationType.create(story: story, name: "Cave", parent: nil)
lt_room = LocationType.create(story: story, name: "Room", parent: nil)

l_winden = Location.create(story: story, name: "Winden", location_type: lt_town, parent: nil)
l_jonas_huose = Location.create(story: story, name: "Jonas House", location_type: lt_house, parent: l_winden)
l_jonas_room = Location.create(story: story, name: "Jonas Room", location_type: lt_room, parent: l_jonas_huose)
l_winden_cave = Location.create(story: story, name: "Winden Cave", location_type: lt_cave, parent: l_winden)