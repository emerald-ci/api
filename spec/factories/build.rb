require "emerald/api/models/build"

FactoryGirl.define do
  factory :build do
    project { FactoryGirl.create(:project) }
    commit "commit-sha123"
    short_description "some useful git message"
    description "some useful git message with lots of information"
    created_at { DateTime.new(2015, 1, 1, 0, 0, 0, 0) }
    updated_at { DateTime.new(2015, 1, 1, 0, 0, 0, 0) }
  end
end
