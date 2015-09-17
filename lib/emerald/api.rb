require 'sinatra/base'
require 'sinatra_auth_github'
require 'sinatra/activerecord'
require 'rack/cors'

require 'emerald/api/middlewares/log_stream'
require 'emerald/api/models/project'
require 'emerald/api/models/build'
require 'emerald/api/workers/job_worker'

module Emerald
  module API
    class App < Sinatra::Base
      set :database, ENV['DATABASE_URL']
      set :database_extras, { pool: 5, timeout: 3000, encoding: 'unicode' }
      set :public_folder,  settings.root + '/api/public'
      set :views,          settings.root + '/api/views'
      set :session_secret, ENV['SESSION_SECRET']
      enable :sessions
      enable :method_override

      set :github_options, {
        :scopes    => "user",
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
      end


      post '/projects' do
        authenticate!
        project = Project.create(git_url: request_json[:project][:git_url])
        project.as_json.to_json
      end

      get '/projects' do
        authenticate!
        Project.all.each(&:as_json).to_json
      end

      get '/projects/:project_id' do |project_id|
        authenticate!
        Project.find(project_id).as_json.to_json
      end

      post '/projects/:project_id/builds/trigger/github' do |project_id|
        project = Project.find(project_id)
        build = project.builds.create
        job = build.jobs.create(state: :not_running)
        JobWorker.perform_async(job.id)
        job.as_json.to_json
      end

      get '/jobs/:job_id' do |job_id|
        authenticate!
        @scheme = 'ws://'
        @job_id = job_id
        erb :"job.html"
      end
    end
  end
end

