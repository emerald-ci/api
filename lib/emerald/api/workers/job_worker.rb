require 'sidekiq'
require 'emerald/api/models/job'
require 'emerald/api/workers/container_factory'

class JobWorker
  include Sidekiq::Worker

  def perform(job_id)
    @job = Job.find(job_id)

    # this is async
    @job.log_stream do |delivery_info, properties, payload|
      payload = JSON.parse(payload)
      log_line = payload['payload']['log'].strip
      @job.logs.create(content: log_line) if !log_line.empty?
    end

    f = ContainerFactory.new(@job, ENV['FLUENTD_URL'])
    volume_container, git_container, test_runner_container = f.create_containers

    start
    status_code = run_container(git_container)
    if status_code != 0
      @job.logs.create(
        content: "Job errored because git checkout has been unsuccessful (error code: #{status_code})"
      )
      stop(:error)
      return
    end

    status_code = run_container(test_runner_container)
    job_state = { 0 => :passed }.fetch(status_code, :failed)
    stop(job_state)
  rescue => e
    puts e
    puts e.backtrace
    @job.logs.create(
      content: "Job errored unexpectedly."
    )
    stop(:error)
  ensure
    remove_containers(volume_container, git_container, test_runner_container)
  end

  private

  def start
    @job.update!(
      state: :running,
      started_at: Time.now
    )
  end

  def stop(job_state)
    @job.update!(
      state: job_state,
      finished_at: Time.now
    )
  end

  def remove_containers(*containers)
    containers.each { |c| c.delete(force: true) }
  end

  def run_container(container)
    container.start
    result = container.wait(3600) # allow container to run up to one hour
    result['StatusCode']
  end
end
