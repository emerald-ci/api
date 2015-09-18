require 'emerald/api/models/job'

class Log < ActiveRecord::Base
  belongs_to :job

  validates :content, presence: true
end

