user = User.create(email_address: "dark@dark", password: "dark", password_confirmation: "dark")

story = Story.create(name: "Dark", owner: user, slug: "dark", private: false)

st_season = SectionType.create(story: story, name: "Season", parent: nil)
st_episode = SectionType.create(story: story, name: "Episode", parent: st_season)