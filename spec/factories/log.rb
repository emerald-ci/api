require "emerald/api/models/log"

FactoryGirl.define do
  factory :log do
    job { FactoryGirl.create(:job) }
    content "log line content"
  end
end
