require 'emerald/api/models/build'
require 'emerald/api/models/log'

class Job < ActiveRecord::Base
  has_many :logs
  belongs_to :build
  enum state: [ :not_running, :running, :passed, :failed ]

  validates :state, presence: true
end

