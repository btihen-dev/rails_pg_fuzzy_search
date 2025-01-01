class Role < ApplicationRecord
  belongs_to :person

  validates :job_title, presence: true
  validates :department, presence: true

  validates :person_id, uniqueness: { scope: [:job_title, :department] }
end
