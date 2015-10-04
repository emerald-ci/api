require 'sidekiq'
require 'redis-mutex'
require 'emerald/api/models/github_repo'
require 'octokit'
require 'emerald/api/event_emitter'

class GithubSyncWorker
  include Sidekiq::Worker

  def perform(github_user_id, access_token)
    mutex = self.class.mutex_for_github_user(github_user_id)
    if mutex.lock
      begin
        client = Octokit::Client.new(access_token: access_token)
        github_sync(client)
      ensure
        mutex.unlock
        EventEmitter.emit({
          event_type: :done,
          type: :github_sync,
          user: github_user_id
        }.to_json)
      end
    end
  end

  def github_sync(github_client)
    github_user = github_client.user
    GithubRepo.where(github_user_id: github_user.id).destroy_all
    repos = github_client.repositories
    github_client.organizations.each do |org|
      repos += github_client.organization_repositories(org.id)
    end
    repos.each do |repo|
      GithubRepo.create(
        full_name: repo.full_name,
        github_repo_id: repo.id,
        github_user_id: github_user.id
      )
    end
  end

  def self.mutex_for_github_user(github_user_id)
    RedisMutex.new("sync_github_repo_for_user_#{github_user_id}", block: 0, expire: 1200)
  end
end
