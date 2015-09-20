class Build < ActiveRecord::Base
  has_many :jobs
  belongs_to :project

  validates :short_description, presence: true
  validates :description, presence: true

  default_scope { order('created_at DESC') }

  before_validation(on: :create) do
    self.short_description = self.description.split("\n").first[0..68]
  end

  def latest_job_result
    latest_job = self.jobs.order(started_at: :desc).first
    return nil if latest_job.nil?
    latest_job.state
  end

  def project_id
    self.project.id
  end

  def serialize_json
    self.as_json(methods: [:latest_job_result, :project_id])
  end

  after_create do
    EventEmitter.emit({
      event_type: :new,
      type: :build,
      data: self.serialize_json
    }.to_json)
  end
end

