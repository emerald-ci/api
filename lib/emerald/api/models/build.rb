class Build < ActiveRecord::Base
  has_many :jobs
  belongs_to :project
end

