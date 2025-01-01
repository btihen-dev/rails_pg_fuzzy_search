# Step 1: People Data
people_data = [
  {
    last_name: "Smith",
    first_name: "John",
    birthdate: Date.new(1980, 1, 1),
    job_title: "Software Engineer",
    enabled: true,
    username: "johnsmith",
    email: "Smith.John@example.com",
    department: "Product"
  },
  {
    last_name: "Johnson",
    first_name: "John",
    birthdate: Date.new(1970, 1, 1),
    job_title: "Network Engineer",
    enabled: true,
    username: "johnjohnson",
    email: "John.Johnson@example.com",
    department: "Operations"
  },
  {
    last_name: "Johanson",
    first_name: "Jonathan",
    birthdate: Date.new(1972, 1, 1),
    job_title: "QA Engineer",
    enabled: true,
    username: "jonathanjohanson",
    email: "Jonathan.Johanson@example.com",
    department: "Quality"
  },
  {
    last_name: "Smithers",
    first_name: "Charles",
    birthdate: Date.new(1974, 1, 1),
    job_title: "Tester",
    enabled: true,
    username: "charlessmithers",
    email: "Charles.Smithers@example.com",
    department: "Quality"
  },
  {
    last_name: "Brown",
    first_name: "Charlie",
    birthdate: Date.new(1960, 1, 1),
    job_title: "Designer",
    enabled: false,
    username: "charliebrown",
    email: "Charlie.Brown@example.com",
    department: "Product"
  },
  {
    last_name: "Johnson",
    first_name: "Emma",
    job_title: "Data Scientist",
    birthdate: Date.new(1962, 1, 1),
    enabled: true,
    username: "emmajohnson",
    email: "Emma.Johnson@example.com",
    department: "Research"
  },
  {
    last_name: "Johnston",
    first_name: "Emilia",
    job_title: "Data Scientist",
    birthdate: Date.new(1966, 1, 1),
    enabled: true,
    username: "emiliajohnston",
    email: "Emilia.Johnston@example.com",
    department: "Research"
  },
  {
    last_name: "Williams",
    first_name: "Liam",
    birthdate: Date.new(1968, 1, 1),
    job_title: "DevOps Engineer",
    enabled: false,
    username: "liamwilliams",
    email: "Liam.Williams@example.com",
    department: "Operations"
  },
  {
    last_name: "Jones",
    first_name: "Olivia",
    birthdate: Date.new(1976, 1, 1),
    job_title: "UX Researcher",
    enabled: true,
    username: "oliviajones",
    email: "Olivia.Jones@example.com",
    department: "Research"
  },
  {
    last_name: "Miller",
    first_name: "Noah",
    birthdate: Date.new(1978, 1, 1),
    job_title: "Software Engineer",
    enabled: false,
    username: "noahmiller",
    email: "Noah.Miller@example.com",
    department: "Product"
  },
  {
    last_name: "Davis",
    first_name: "Ava",
    birthdate: Date.new(1982, 1, 1),
    job_title: "Software Engineer",
    enabled: true,
    username: "avadavis",
    email: "Ava.Davis@example.com",
    department: "Product"
  },
  {
    last_name: "Garcia",
    first_name: "Sophia",
    birthdate: Date.new(1984, 1, 1),
    job_title: "QA Engineer",
    enabled: false,
    username: "sophiagarcia",
    email: "Sophia.Garcia@example.com",
    department: "Quality"
  },
  {
    last_name: "Rodriguez",
    first_name: "Isabella",
    birthdate: Date.new(1986, 1, 1),
    job_title: "Tech Support",
    enabled: true,
    username: "isabellarodriguez",
    email: "Isabella.Rodriguez@example.com",
    department: "Customers"
  },
  {
    last_name: "Martinez",
    first_name: "Mason",
    birthdate: Date.new(1988, 1, 1),
    job_title: "Business Analyst",
    enabled: true,
    username: "masonmartinez",
    email: "Mason.Martinez@example.com",
    department: "Research"
  },
  {
    last_name: "Hernandez",
    first_name: "Lucas",
    birthdate: Date.new(1958, 1, 1),
    job_title: "Systems Administrator",
    enabled: false,
    username: "lucashernandez",
    email: "Lucas.Hernandez@example.com",
    department: "Operations"
  },
  {
    last_name: "Lopez",
    first_name: "Amelia",
    birthdate: Date.new(1956, 1, 1),
    job_title: "Product Manager",
    enabled: true,
    username: "amelialopez",
    email: "Amelia.Lopez@example.com",
    department: "Business"
  },
  {
    last_name: "Gonzalez",
    first_name: "James",
    birthdate: Date.new(1990, 1, 1),
    job_title: "Network Engineer",
    enabled: false,
    username: "jamesgonzalez",
    email: "James.Gonzalez@example.com",
    department: "Operations"
  },
  {
    last_name: "Wilson",
    first_name: "Elijah",
    birthdate: Date.new(1992, 1, 1),
    job_title: "Cloud Architect",
    enabled: true,
    username: "elijahwilson",
    email: "Elijah.Wilson@example.com",
    department: "Operations"
  }
]

# Step 2: Insert People and Assign Accounts & Departments
people_data.each do |person_data|
  # Insert the Person record
  person =
    Person.create(
      first_name: person_data[:first_name],
      last_name: person_data[:last_name],
      birthdate: person_data[:birthdate]
    )

  # Insert the corresponding Role
  Role.create!(
    person_id: person.id,
    job_title: person_data[:job_title],
    department: person_data[:department]
  )

  # # Insert the corresponding Account record
  # Account.create!(
  #   person_id: person.id,
  #   username: person_data[:username],
  #   email: person_data[:email],
  #   enabled: person_data[:enabled]
  # )
end
