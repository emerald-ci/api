require 'yaml'
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
      @job.add_to_log(log_line) if !log_line.empty?
    end

    f = ContainerFactory.new(@job, ENV['FLUENTD_URL'])
    containers = []
    volume_container, git_container, config_container, test_runner_container = f.create_containers
    containers = [volume_container, git_container, config_container, test_runner_container]

    start
    status_code = run_container(git_container)
    if status_code != 0
      @job.add_to_log(
        "Build errored because git checkout has been unsuccessful (error code: #{status_code})"
      )
      stop(:error)
      return
    end

    config_container.start
    config_container.wait
    config = config_container.logs(stdout: true)
    config = YAML.load(config)

    status_code = run_container(test_runner_container)
    job_state = { 0 => :passed }.fetch(status_code, :failed)

    plugin_configs = config.delete("plugins")
    if !plugin_configs.nil?
      plugin_containers = f.create_plugin_containers(plugin_configs)
      containers += plugin_containers
      plugin_containers.each_with_index do |container, index|
        run_container(
          container,
          {
            job: {
              state: job_state
            },
            config: plugin_configs[index]
          }.to_json
        )
      end
    end

    @job.add_to_log("Build #{job_state}")
    stop(job_state)
  rescue => e
    puts e
    puts e.backtrace
    @job.add_to_log("Job errored unexpectedly.")
    stop(:error)
  ensure
    remove_containers(containers)
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

  def remove_containers(containers)
    containers.each { |c| c.delete(force: true) }
  end

  def run_container(container, stdin = nil)
    container.start
    container.attach(stdin: StringIO.new(stdin.to_s)) if !stdin.nil?
    result = container.wait(3600) # allow container to run up to one hour
    result['StatusCode']
  end
end
