require "emerald/api/models/job"

FactoryGirl.define do
  factory :job do
    build { FactoryGirl.create(:build) }
    state :passed
    started_at { DateTime.new(2015, 1, 1, 0, 0, 0, 0) }
    finished_at { DateTime.new(2015, 1, 1, 0, 0, 0, 0) }
  end
end
