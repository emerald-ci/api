require 'uri'

class Project < ActiveRecord::Base
  has_many :builds

  validates :git_url, format: { with: URI::regexp, message: 'is not a valid URL' }, presence: true

  def latest_build_result
    latest_build = self.builds.order(created_at: :desc).first
    return nil if latest_build.nil?
    latest_build.latest_job_result
  end

  def serialize_json
    self.as_json(only: [:id, :name, :type, :git_url], methods: :latest_build_result)
  end
end

