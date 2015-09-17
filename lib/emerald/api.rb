require 'sinatra/base'

require 'emerald/api/middlewares/log_stream'

module Emerald
  module API
    class App < Sinatra::Base
      set :public_folder,  settings.root + '/api/public'
      set :views,          settings.root + '/api/views'
      set :session_secret, ENV['SESSION_SECRET']
      enable :sessions
      enable :method_override

      use LogStream

      get '/jobs/:job_id' do
        @scheme = 'ws://'
        @job_id = params['job_id']
        erb :"job.html"
      end
    end
  end
end

