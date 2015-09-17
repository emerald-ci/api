require 'emerald/api/models/project'

class GithubProject < Project
  validates :git_repo_id, presence: true
end

