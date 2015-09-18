require 'faye/websocket'
require 'thread'
require 'bunny'
require 'json'
require 'erb'

module Emerald
  module API
    class LogStream
      KEEPALIVE_TIME = 15 # in seconds
      ROUTE_REGEX = /\/api\/v1\/jobs\/(\d)\/logs/
      COLOR = {
         '1' => 'bold',
        '30' => 'black',
        '31' => 'red',
        '32' => 'green',
        '33' => 'yellow',
        '34' => 'blue',
        '35' => 'magenta',
        '36' => 'cyan',
        '37' => 'white',
        '90' => 'grey'
      }

      def initialize(app)
        @app = app
        conn = Bunny.new ENV['RABBITMQ_URL']
        conn.start
        @ch = conn.create_channel
        @x = @ch.direct('logs', durable: true)
      end

      def call(env)
        route = env['PATH_INFO']
        if Faye::WebSocket.websocket?(env) && !!(ROUTE_REGEX =~ route)
          ws = Faye::WebSocket.new(env, nil, { ping: KEEPALIVE_TIME })
          job_id = route.scan(ROUTE_REGEX).first.first

          ws.on :open do |event|
            q = @ch.queue('', auto_delete: true).bind(@x, routing_key: "job.#{job_id}")
            q.subscribe do |delivery_info, properties, payload|
              payload = JSON.parse(payload)
              log_line = ansi2html(payload['payload']['log']) + "\n"
              Log.create(content: log_line, job_id: job_id)
              payload['payload']['log'] = log_line
              ws.send(payload.to_json)
            end
          end

          ws.on :close do |event|
            ws = nil
          end

          # Return async Rack response
          ws.rack_response
        else
          @app.call(env)
        end
      end

      def ansi2html(input)
        out = String.new
        s = StringScanner.new(input.gsub("<", "&lt;"))
        while(!s.eos?)
          if s.scan(/\e\[(3[0-7]|90|1)m/)
            out << %{<span class="#{COLOR[s[1]]}">}
          else
            if s.scan(/\e\[0m/)
              out << %{</span>}
            else
              out << s.scan(/./m)
            end
          end
        end
        out
      end
    end
  end
end
