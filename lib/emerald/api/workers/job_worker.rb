require_relative '../../../../config/environment'
require 'emerald/api'

require 'sidekiq'
require 'docker'
require 'emerald/api/models/job'

class JobWorker
  include Sidekiq::Worker

  def perform(job_id)
    job = Job.find(job_id)
    container = create_container(job)
    job.update(
      state: :running,
      started_at: Time.now
    )
    container.start
    statusCode = container.wait(3600)['StatusCode'] # allow jobs to take up to one hour
    jobState = { 0 => :passed }.fetch(statusCode, :failed)
    job.update(
      state: jobState,
      finished_at: Time.now
    )
  end

  def create_container(job)
    Docker::Container.create(
      'Cmd' => [job.build.project.git_url, job.build.commit],
      'Image' => 'emeraldci/environment',
      'Tty' => true,
      'OpenStdin' => true,
      'HostConfig' => {
        'Privileged' => true,
        'Binds' => ['/var/run/docker.sock:/var/run/docker.sock'],
        'LogConfig' => {
          'Type' => 'fluentd',
          'Config' => {
            'fluentd-address' => ENV['FLUENTD_URL'],
            'fluentd-tag' => "job.#{job.id}"
          }
        }
      }
    )
  end
end
