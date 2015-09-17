require 'emerald/api/models/build'

class Job < ActiveRecord::Base
  has_many :jobs
  belongs_to :build
  enum state: [ :not_running, :running, :passed, :failed ]

  validates :state, presence: true
end

