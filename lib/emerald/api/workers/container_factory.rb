require 'docker'

class ContainerFactory
  def initialize(job, fluentd_url)
    @job = job
    @fluentd_url = fluentd_url
  end

  def create_containers
    volume_container = create_volume_container
    git_container = create_git_container
    config_container = create_config_container
    test_runner_container = create_test_runner_container
    [volume_container, git_container, config_container, test_runner_container]
  end

  def create_plugin_containers(configs)
    configs.map do |config|
      create_plugin_container(config["plugin_image"])
    end
  end

  private

  def create_volume_container
    create_container({
      'Image' => 'alpine',
      'name' => volume_container_name,
      'Cmd' => ['/bin/true'],
      'Volumes' => {
        '/project' => {},
      },
      'HostConfig' => {
        'Binds' => ['/var/run/docker.sock:/var/run/docker.sock']
      }
    })
  end

  def create_git_container
    create_container({
      'Image' => 'emeraldci/git',
      'Cmd' => [@job.build.project.git_url, @job.build.commit],
      'Tty' => true,
      'OpenStdin' => true,
      'HostConfig' => {
        'VolumesFrom' => [volume_container_name],
        'LogConfig' => fluentd_log_config
      }
    })
  end

  def create_config_container
    create_container({
      'Image' => 'alpine',
      'Cmd' => ['/bin/cat', '/project/.emerald.yml'],
      'Tty' => true,
      'HostConfig' => {
        'VolumesFrom' => [volume_container_name],
      }
    })
  end

  def create_test_runner_container
    create_container({
      'Image' => 'emeraldci/test-runner',
      'Cmd' => ["-project=job#{@job.id}"],
      'Stdin' => true,
      'Tty' => true,
      'HostConfig' => {
        'VolumesFrom' => [volume_container_name],
        'LogConfig' => fluentd_log_config
      }
    })
  end

  def create_plugin_container(image)
    create_container({
      'Image' => image,
      'AttachStdin' => true,
      'AttachStdout' => true,
      'OpenStdin' => true,
      'StdinOnce' => true,
      'HostConfig' => {
        'VolumesFrom' => [volume_container_name]
      }
    })
  end

  def create_container(config = {})
    ensure_image_exists config["Image"]
    Docker::Container.create(config)
  end

  def fluentd_log_config
    {
      'Type' => 'fluentd',
      'Config' => {
        'fluentd-address' => @fluentd_url,
        'fluentd-tag' => "job.#{@job.id}"
      }
    }
  end

  def ensure_image_exists(image_name)
    Docker::Image.create('fromImage' => image_name) if !Docker::Image.exist?(image_name)
  end
end
