require 'emerald/api/models/project'

FactoryGirl.define do
  factory :project, class: Project do
    git_url 'https://github.com/emerald-ci/ruby-example'
  end
end
