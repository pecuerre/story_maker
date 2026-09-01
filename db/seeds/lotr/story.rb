user = User.create(
  email_address: "lotr@lotr",
  password: "lotr",
  password_confirmation: "lotr"
)

story = Story.create(
  name: "Lord of the Rings",
  owner: user,
  slug: "lotr",
  private: true
)