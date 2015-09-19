class Build < ActiveRecord::Base
  has_many :jobs
  belongs_to :project

  validates :short_description, presence: true
  validates :description, presence: true

  before_validation(on: :create) do
    self.short_description = self.description.split("\n").first[0..68]
  end

  def latest_job_result
    latest_job = self.jobs.order(started_at: :desc).first
    return nil if latest_job.nil?
    latest_job.state
  end
end

