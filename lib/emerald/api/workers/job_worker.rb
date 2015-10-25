require "yaml"
require "sidekiq"
require "docker"
require "emerald/api/models/job"
require "emerald/api/workers/container_factory"

class JobWorker
  class Container
    attr_reader :container, :docker_create_opts
    private :container, :docker_create_opts

    def initialize(docker_create_opts)
      @docker_create_opts = docker_create_opts
    end

    def create
      ensure_image_exists(docker_create_opts["Image"])
      @container = Docker::Container.create(docker_create_opts)
      self
    end

    def log_capturer(l = nil)
      return @log_capturer if l.nil?
      @log_capturer = l
      self
    end

    def stdin(pipe_string = nil)
      return @stdin if pipe_string.nil?
      @stdin = StringIO.new(pipe_string.to_s)
      self
    end

    def run
      Thread.new do
        container.attach(tty: true) do |stream, chunk|
          str = stream.gsub("\0", "")
          $stdout.write(str)
          log_capturer.add_chunk(str) if !log_capturer.nil?
        end
      end
      container.start
      container.attach(stdin: stdin) if !stdin.nil?
      dockerResponse = container.wait(3600) # allow container to run up to one hour
      dockerResponse["StatusCode"]
    end

    def remove
      container.delete(force: true) if !container.nil?
    end

    def logs
      container.logs(stdout: true)
    end

    private

    def ensure_image_exists(image_name)
      Docker::Image.create("fromImage" => image_name) if !Docker::Image.exist?(image_name)
    end
  end

  class VolumeContainer < Container
    def initialize(job)
      super({
        "Image" => "alpine",
        "name" => job.volume_container_name,
        "Cmd" => ["/bin/true"],
        "Volumes" => {
          "/project" => {},
        },
        "HostConfig" => {
          "Binds" => ["/var/run/docker.sock:/var/run/docker.sock"]
        }
      })
    end
  end

  class GitContainer < Container
    def initialize(job)
      super({
        "Image" => "emeraldci/git",
        "Cmd" => [job.build.project.git_url, job.build.commit],
        "Tty" => true,
        "OpenStdin" => true,
        "HostConfig" => {
          "VolumesFrom" => [job.volume_container_name],
        }
      })
    end
  end

  class ConfigContainer < Container
    def initialize(job)
      super({
        "Image" => "alpine",
        "Cmd" => ["/bin/cat", "/project/.emerald.yml"],
        "Tty" => true,
        "HostConfig" => {
          "VolumesFrom" => [job.volume_container_name],
        }
      })
    end
  end

  class TestRunnerContainer < Container
    def initialize(job)
      super({
        "Image" => "emeraldci/test-runner",
        "Cmd" => ["-project=job#{job.id}"],
        "Stdin" => true,
        "Tty" => true,
        "HostConfig" => {
          "VolumesFrom" => [job.volume_container_name],
        }
      })
    end
  end

  class PluginContainer < Container
    def initialize(job, image)
      super({
        "Image" => image,
        "AttachStdin" => true,
        "AttachStdout" => true,
        "OpenStdin" => true,
        "StdinOnce" => true,
        "HostConfig" => {
          "VolumesFrom" => [job.volume_container_name],
        }
      })
    end
  end

  class LogCapturer
    attr_reader :job, :x, :conn
    private :job, :x, :conn

    def initialize(job)
      @job = job
      @conn = Bunny.new ENV["RABBITMQ_URL"]
      @conn.start
      ch = conn.create_channel
      @x = ch.direct("logs", durable: true)
    end

    def close
      x.delete
      conn.close
    end

    def add_chunk(chunk)
      if !chunk.empty?
        x.publish(chunk, routing_key: job.id.to_s)
        job.add_to_log(chunk)
      end
    end
  end

  include Sidekiq::Worker

  def perform(job_id)
    @job = Job.find(job_id)
    l = LogCapturer.new(@job)
    containers = []
    job_state = :error

    volume_container = VolumeContainer.new(@job).log_capturer(l).create
    git_container = GitContainer.new(@job).log_capturer(l).create
    config_container = ConfigContainer.new(@job).create
    test_runner_container = TestRunnerContainer.new(@job).log_capturer(l).create
    containers = [volume_container, git_container, config_container, test_runner_container]

    start
    status_code = git_container.run
    if status_code != 0
      l.add_chunk(
        "Build errored because git checkout has been unsuccessful (error code: #{status_code})"
      )
      return
    end

    config_container.run
    config = config_container.logs
    config = YAML.load(config)

    status_code = test_runner_container.run
    job_state = { 0 => :passed }.fetch(status_code, :failed)

    plugin_configs = config.delete("plugins")
    if !plugin_configs.nil?
      plugin_configs.each do |config|
        container = PluginContainer.new(@job, config["plugin_image"]).stdin({
          job: { state: job_state },
          config: config
        }.to_json).log_capturer(l).create
        containers << container
        container.run
      end
    end

    l.add_chunk("Build #{job_state}")
  rescue => e
    puts e
    puts e.backtrace
    l.add_chunk("Job errored unexpectedly.")
  ensure
    stop(job_state)
    containers.each { |c| c.remove }
    l.close
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
end
