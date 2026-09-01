user = User.create(
  email_address: "dark@dark",
  password: "dark",
  password_confirmation: "dark"
)

story = Story.create(
  name: "Dark",
  owner: user,
  slug: "dark"
)