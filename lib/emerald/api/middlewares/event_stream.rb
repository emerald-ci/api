require 'faye/websocket'
require 'thread'
require 'bunny'
require 'json'
require 'erb'

module Emerald
  module API
    class EventStream
      KEEPALIVE_TIME = 15 # in seconds
      ROUTE = '/api/v1/events'

      def initialize(app)
        @app = app
        @clients = {}
        conn = Bunny.new ENV['RABBITMQ_URL']
        conn.start
        ch = conn.create_channel
        x = ch.direct('events', durable: true)
        q = ch.queue('', auto_delete: true).bind(x, routing_key: "events")
        q.subscribe do |delivery_info, properties, payload|
          json = JSON.parse(payload)
          @clients.each do |client_id, ws|
            if !json.key?(:user) || (json.key?(:user) && json[:user] == user_id)
              ws.send(payload)
            end
          end
        end
      end

      def call(env)
        if Faye::WebSocket.websocket?(env) && ROUTE == env['PATH_INFO']
          ws = Faye::WebSocket.new(env, nil, { ping: KEEPALIVE_TIME })

          ws.on :open do |event|
            user = env['warden'].user
            @clients[user.id] = ws
          end

          ws.on :close do |event|
            @clients.delete(ws)
            ws = nil
          end

          # Return async Rack response
          ws.rack_response
        else
          @app.call(env)
        end
      end

    end
  end
end
