require 'emerald/api/models/build'
require 'emerald/api/models/log'
require 'bunny'

class Job < ActiveRecord::Base
  has_many :logs
  belongs_to :build
  enum state: [ :not_running, :running, :passed, :failed ]

  validates :state, presence: true

  def log_stream(&block)
    conn = Bunny.new ENV['RABBITMQ_URL']
    conn.start
    ch = conn.create_channel
    x = ch.direct('logs', durable: true)
    q = ch.queue('', auto_delete: true).bind(x, routing_key: "job.#{id}")
    q.subscribe(&block)
  end
end

