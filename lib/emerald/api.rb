require 'sinatra/base'
require 'sinatra_auth_github'
require 'sinatra/activerecord'
require 'rack/cors'

require 'emerald/api/middlewares/log_stream'
require 'emerald/api/models/github_project'
require 'emerald/api/models/plain_project'
require 'emerald/api/models/build'
require 'emerald/api/workers/job_worker'

module Emerald
  module API
    class App < Sinatra::Base
      set :database, ENV['DATABASE_URL']
      set :database_extras, { pool: 5, timeout: 3000, encoding: 'unicode' }
      set :session_secret, ENV['SESSION_SECRET']
      enable :sessions
      enable :method_override

      set :github_options, {
        :scopes    => "user, repo, write:repo_hook",
        :secret    => ENV['GITHUB_CLIENT_SECRET'],
        :client_id => ENV['GITHUB_CLIENT_ID'],
      }

      use Rack::Cors do
        allow do
          origins '*'
          resource '*', headers: :any, methods: [:get, :post, :patch, :put, :delete]
        end
      end
      register Sinatra::ActiveRecordExtension
      register Sinatra::Auth::Github
      use LogStream

      helpers do
        def request_body
          result = request.body.gets
          request.body.rewind
          result
        end

        def request_json
          content = request_body
          content ||= '{}'
          JSON.parse content, symbolize_names: true
        end

        def serialize_project(project)
          project.as_json(only: [:id, :name, :type, :git_url])
        end
      end

      get '/api/v1/github/repos' do
        authenticate!
        repos = github_user.api.repositories
        github_user.api.organizations.each do |org|
          github_user.api.organization_repositories(org.login)
        end
        repos.map do |repo|
          { id: repo.id, full_name: repo.full_name }
        end.to_json
      end

      post '/api/v1/github/repos/:id' do |id|
        authenticate!
        repo = github_user.api.repository(id)
        project = GithubProject.create!(github_repo_id: id, name: repo.full_name, git_url: repo.url)
        serialize_project(project).to_json
      end

      post '/api/v1/projects' do
        authenticate!
        project = PlainProject.create!(name: request_json[:name], git_url: request_json[:git_url])
        serialize_project(project).to_json
      end

      get '/api/v1/projects' do
        authenticate!
        Project.all.map{ |p| serialize_project(p) }.to_json
      end

      get '/api/v1/projects/:project_id' do |project_id|
        authenticate!
        serialize_project(Project.find(project_id)).to_json
      end

      delete '/api/v1/project/:project_id' do |project_id|
        authenticate!
        Project.find(project_id).delete!
        status 204
      end

      get '/api/v1/projects/:project_id/builds' do |project_id|
        authenticate!
        Project.find(project_id).builds.as_json.to_json
      end

      post '/api/v1/projects/:project_id/builds/trigger/github' do |project_id|
        webhook_payload = request_json
        ref = webhook_payload[:ref]
        commit = webhook_payload[:head_commit]
        project = Project.find(project_id)
        build = project.builds.create!(commit: (commit[:id] || ref || 'master'), description: commit[:message])
        job = build.jobs.create!(state: :not_running)
        JobWorker.perform_async(job.id)
        job.as_json.to_json
      end

      get '/api/v1/builds/:build_id' do |build_id|
        authenticate!
        Build.find(build_id).as_json.to_json
      end

      get '/api/v1/builds/:build_id/jobs' do |build_id|
        authenticate!
        Build.find(build_id).jobs.as_json.to_json
      end

      get '/api/v1/jobs/:job_id' do |job_id|
        authenticate!
        Job.find(job_id).as_json.to_json
      end
    end
  end
end

