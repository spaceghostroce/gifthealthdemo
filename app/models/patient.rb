# A patient at the pharmacy. One patient can have many prescriptions.
class Patient < ApplicationRecord
  has_many :prescriptions, dependent: :destroy
  validates :name, presence: true
end
