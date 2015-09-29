require 'sinatra/base'
require 'sinatra_auth_github'
require 'sinatra/activerecord'
require 'rack/cors'

require 'emerald/api/middlewares/log_stream'
require 'emerald/api/middlewares/event_stream'
require 'emerald/api/models/github_project'
require 'emerald/api/models/github_repo'
require 'emerald/api/models/plain_project'
require 'emerald/api/models/build'
require 'emerald/api/workers/job_worker'

module Emerald
  module API
    class APIError < StandardError
      attr_reader :status_code

      def initialize(status_code, *messages)
        @status_code = status_code
        @messages = messages
      end

      def to_json
        { errors: @messages }.to_json
      end
    end

    class UnprocessableEntity < APIError
      def initialize(*messages)
        super(422, *messages)
      end
    end

    class App < Sinatra::Base
      set :database, ENV['DATABASE_URL']
      set :database_extras, { pool: 5, timeout: 3000, encoding: 'unicode' }
      set :session_secret, ENV['SESSION_SECRET']
      enable :sessions
      disable :raise_errors, :show_exceptions, :dump_errors, :logging

      set :github_options, {
        :scopes    => "user, repo, write:repo_hook",
        :secret    => ENV['GITHUB_CLIENT_SECRET'],
        :client_id => ENV['GITHUB_CLIENT_ID'],
        :callback_url => '/api/v1/auth/github/callback'
      }

      register Sinatra::ActiveRecordExtension
      register Sinatra::Auth::Github
      use LogStream
      use EventStream

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

        def auth!
          if ENV['GITHUB_ORG'].nil?
            authenticate!
          else
            github_organization_authenticate! ENV['GITHUB_ORG']
          end
        end
      end

      error APIError do
        halt env['sinatra.error'].status_code, env['sinatra.error'].to_json
      end

      get '/api/v1/auth/active' do
        auth!
        { authenticated: authenticated? }.to_json
      end

      get '/api/v1/auth/github/callback' do
        if params["error"]
          redirect "/unauthenticated"
        else
          session['warden.github.oauth']['return_to'] = '/api/v1/auth/github/after'
          authenticate!
          return_to = session.delete('return_to') || _relative_url_for('/')
          redirect return_to
        end
      end

      get '/api/v1/auth/github/after' do
        auth!
        redirect ENV['FRONTEND_URL']
      end

      get '/api/v1/profile' do
        auth!
        github_user.to_h[:attribs].to_json
      end

      get '/api/v1/github/repos' do
        auth!
        GithubRepo.where(github_user_id: github_user.id).map(&:serialize_json).to_json
      end

      post '/api/v1/github/repos/sync' do
        auth!
        repos = github_user.api.repositories(github_user.login)
        github_user.api.organizations.each do |org|
          repos += github_user.api.organization_repositories(org.login)
        end
        GithubRepo.where(github_user_id: github_user.id).destroy_all
        repos.map do |repo|
          GithubRepo.create(
            full_name: repo.full_name,
            github_repo_id: repo.id,
            github_user_id: github_user.id
          ).serialize_json
        end.to_json
      end

      post '/api/v1/github/repos/:id' do |id|
        auth!
        repo = github_user.api.repo(id.to_i)
        if GithubProject.exists?(github_repo_id: repo.id)
          fail UnprocessableEntity, 'Github repo has already been added'
        end
        project = GithubProject.create!(github_repo_id: repo.id, name: repo.full_name, git_url: repo.clone_url)
        #cleanup earlier hooks
        github_user.api.hooks(repo.full_name).each do |hook|
          if !hook.config.url.nil? && hook.config.url.include?(request.env['HTTP_HOST'])
            github_user.api.remove_hook(repo.full_name, hook.id)
          end
        end
        #add new hook
        github_user.api.create_hook(
          repo.full_name,
          'web',{
            :url => "http://#{request.env['HTTP_HOST']}/api/v1/projects/#{project.id}/builds/trigger/github",
            :content_type => 'json'
          },
          {
            :events => ['push'], # possibility for pull requests add 'pull_request'
            :active => true
          }
        )
        project.serialize_json.to_json
      end

      post '/api/v1/projects' do
        auth!
        project = PlainProject.create!(name: request_json[:name], git_url: request_json[:git_url])
        project.serialize_json.to_json
      end

      get '/api/v1/projects' do
        auth!
        Project.all.map(&:serialize_json).to_json
      end

      get '/api/v1/projects/:project_id' do |project_id|
        auth!
        Project.find(project_id).serialize_json.to_json
      end

      delete '/api/v1/project/:project_id' do |project_id|
        auth!
        Project.find(project_id).delete!
        status 204
      end

      get '/api/v1/projects/:project_id/builds' do |project_id|
        auth!
        Project.find(project_id).builds.map(&:serialize_json).to_json
      end

      post '/api/v1/projects/:project_id/builds/trigger/manual' do |project_id|
        auth!
        project = GithubProject.find(project_id)
        commit = github_user.api.commits(project.name, 'master').first.commit
        build = project.builds.create!(commit: 'master', description: commit[:message])
        job = build.jobs.create!(state: :not_running)
        JobWorker.perform_async(job.id)
        job.serialize_json.to_json
      end

      post '/api/v1/projects/:project_id/builds/trigger/github' do |project_id|
        webhook_payload = request_json
        ref = webhook_payload[:ref]
        commit = webhook_payload[:head_commit]
        project = Project.find(project_id)
        build = project.builds.create!(commit: (commit[:id] || ref || 'master'), description: commit[:message])
        job = build.jobs.create!(state: :not_running)
        JobWorker.perform_async(job.id)
        job.serialize_json.to_json
      end

      get '/api/v1/builds/:build_id' do |build_id|
        auth!
        Build.find(build_id).serialize_json.to_json
      end

      get '/api/v1/builds/:build_id/jobs' do |build_id|
        auth!
        Build.find(build_id).jobs.map(&:serialize_json).to_json
      end

      get '/api/v1/jobs/:job_id' do |job_id|
        auth!
        Job.find(job_id).serialize_json.to_json
      end

      get '/api/v1/jobs/:job_id/log' do |job_id|
        auth!
        Job.find(job_id).logs.map(&:html_log_line).to_json
      end
    end
  end
end

