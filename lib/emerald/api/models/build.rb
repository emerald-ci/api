class Build < ActiveRecord::Base
  has_many :jobs
  belongs_to :project

  validates :short_description, presence: true
  validates :description, presence: true

  before_validation(on: :create) do
    self.short_description = self.description.split("\n").first[0..68]
  end
end

