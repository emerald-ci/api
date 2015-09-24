require 'docker'

class ContainerFactory
  def initialize(job, fluentd_url)
    @job = job
    @fluentd_url = fluentd_url
  end

  def create_containers
    containers = []
    volume_container = create_volume_container
    git_container = create_git_container
    test_runner_container = create_test_runner_container
    [volume_container, git_container, test_runner_container]
  end

  private

  def create_volume_container
    create_container('alpine', {
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
    create_container('emeraldci/git', {
      'Cmd' => [@job.build.project.git_url, @job.build.commit]
    })
  end

  def create_test_runner_container
    create_container('emeraldci/test-runner')
  end

  def create_container(image, override_config = {})
    ensure_image_exists image
    Docker::Container.create(
      container_config(override_config).merge({
        'Image' => image
      })
    )
  end

  def container_config(override)
    base_config.merge(override)
  end

  def base_config
    {
      'Cmd' => [],
      'Tty' => true,
      'OpenStdin' => true,
      'HostConfig' => {
        'VolumesFrom' => [volume_container_name],
        'LogConfig' => {
          'Type' => 'fluentd',
          'Config' => {
            'fluentd-address' => @fluentd_url,
            'fluentd-tag' => "job.#{@job.id}"
          }
        }
      }
    }
  end

  def volume_container_name
    "job_#{@job.id}_volume_container"
  end

  def ensure_image_exists(image_name)
    Docker::Image.create('fromImage' => image_name) if !Docker::Image.exist?(image_name)
  end
end
