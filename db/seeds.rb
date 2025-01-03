# Step 1: People Data
people_data = [
  {
    last_name: "Smith",
    first_name: "John",
    job_title: "Software Engineer",
    department: "Product"
  },
  {
    last_name: "Johnson",
    first_name: "John",
    job_title: "Network Engineer",
    department: "Operations"
  },
  {
    last_name: "Johanson",
    first_name: "Jonathan",
    job_title: "QA Engineer",
    department: "Quality"
  },
  {
    last_name: "Smithers",
    first_name: "Charles",
    job_title: "Tester",
    department: "Quality"
  },
  {
    last_name: "Brown",
    first_name: "Charlie",
    job_title: "Designer",
    department: "Product"
  },
  {
    last_name: "Johnson",
    first_name: "Emma",
    job_title: "Network Engineer",
    department: "Operations"
  },
  {
    last_name: "Johnston",
    first_name: "Emilia",
    job_title: "Data Scientist",
    department: "Research"
  },
  {
    last_name: "Williams",
    first_name: "Liam",
    job_title: "DevOps Engineer",
    department: "Operations"
  },
  {
    last_name: "Jones",
    first_name: "Olivia",
    job_title: "UX Researcher",
    department: "Research"
  },
  {
    last_name: "Miller",
    first_name: "Noah",
    job_title: "Software Engineer",
    department: "Product"
  },
  {
    last_name: "Davis",
    first_name: "Ava",
    job_title: "Software Engineer",
    department: "Product"
  },
  {
    last_name: "Garcia",
    first_name: "Sophia",
    job_title: "QA Engineer",
    department: "Quality"
  },
  {
    last_name: "Rodriguez",
    first_name: "Isabella",
    job_title: "Tech Support",
    department: "Customers"
  },
  {
    last_name: "Martinez",
    first_name: "Mason",
    job_title: "Business Analyst",
    department: "Research"
  },
  {
    last_name: "Hernandez",
    first_name: "Lucas",
    job_title: "Systems Administrator",
    department: "Operations"
  },
  {
    last_name: "Lopez",
    first_name: "Amelia",
    job_title: "Product Manager",
    department: "Business"
  },
  {
    last_name: "Gonzalez",
    first_name: "James",
    job_title: "Network Engineer",
    department: "Operations"
  },
  {
    last_name: "Wilson",
    first_name: "Elijah",
    job_title: "Cloud Architect",
    department: "Operations"
  }
]

# Step 2: Insert People and Assign Accounts & Departments
people_data.each do |person_data|
  # Insert the Person record
  person =
    Person.create(
      first_name: person_data[:first_name],
      last_name: person_data[:last_name]
    )

  # Insert the corresponding Role
  Role.create!(
    person_id: person.id,
    job_title: person_data[:job_title],
    department: person_data[:department]
  )
end
