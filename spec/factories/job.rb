require "emerald/api/models/job"

FactoryGirl.define do
  factory :job do
    build { FactoryGirl.create(:build) }
    state :passed
    started_at { DateTime.new(2015, 1, 1, 0, 0, 0, 0) }
    finished_at { DateTime.new(2015, 1, 1, 0, 0, 0, 0) }
    log <<-EOF.strip_heredoc.chomp
      not colored
      [33mcolored[0m
      not colored
    EOF
  end
end
