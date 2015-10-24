require 'emerald/api/models/build'
require 'emerald/api/event_emitter'
require 'bunny'

class Job < ActiveRecord::Base
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

  has_many :logs
  belongs_to :build
  enum state: [ :not_running, :running, :passed, :failed, :error ]

  validates :state, presence: true

  default_scope { order('started_at DESC') }

  def log_stream(&block)
    conn = Bunny.new ENV['RABBITMQ_URL']
    conn.start
    ch = conn.create_channel
    x = ch.direct('logs', durable: true)
    q = ch.queue('', auto_delete: true).bind(x, routing_key: "job.#{id}")
    q.subscribe(&block)
  end

  def add_to_log(content)
    self.log = "#{log}\n#{content}"
    save
  end

  def self.s_to_html(content)
    out = String.new
    s = StringScanner.new((content.to_s + "\n").gsub("<", "&lt;"))
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
    out.chomp
  end

  def html_log
    self.class.s_to_html(log)
  end

  def build_id
    self.build.id
  end

  def project_id
    self.build.project.id
  end

  def serialize_json
    as_json(methods: [:build_id, :project_id], except: [:log])
  end

  after_create do
    EventEmitter.emit({
      event_type: :new,
      type: :job,
      data: serialize_json
    }.to_json)
  end

  after_update do
    EventEmitter.emit({
      event_type: :update,
      type: :job,
      data: serialize_json
    }.to_json)
  end
end

