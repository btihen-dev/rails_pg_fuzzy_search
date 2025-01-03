class Person < ApplicationRecord
  has_many :accounts
  has_many :roles

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :first_name, uniqueness: { scope: [:last_name] }
end
