require 'uri'

class Project < ActiveRecord::Base
  has_many :builds

  validates :git_url, format: { with: URI::regexp, message: 'is not a valid URL' }, presence: true
end

