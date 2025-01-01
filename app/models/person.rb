class Person < ApplicationRecord
  has_many :accounts
  has_many :roles

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :birthdate, presence: true
  validates :birthdate, uniqueness: { scope: [:first_name, :last_name] }
end
