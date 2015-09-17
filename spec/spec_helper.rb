# This file was generated by the `rspec --init` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# The generated `.rspec` file contains `--require spec_helper` which will cause
# this file to always be loaded, without a need to explicitly require it in any
# files.
#
# Given that it is always loaded, you are encouraged to keep this file as
# light-weight as possible. Requiring heavyweight dependencies from this file
# will add to the boot time of your test suite on EVERY test run, even for an
# individual file that may not need all of that loaded. Instead, consider
# making a separate helper file that requires the additional dependencies and
# performs the additional setup, and require it from the spec files that
# actually need it.
#
# The `.rspec` file also contains a few flags that are not defaults but that
# users commonly want.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration

unless ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

if ENV['CI']
  require 'codeclimate-test-reporter'
  CodeClimate::TestReporter.start
end

ENV['SECRET_KEY'] = 'le_super_secret_key'
ENV['RACK_ENV'] = 'test'

require 'active_record'
ActiveRecord::Migration.maintain_test_schema!

require File.expand_path("../../config/environment", __FILE__)
require 'emerald/api'
require 'database_cleaner'
require 'climate_control'
require 'rack/test'
require 'json'
require 'factory_girl'

Dir[File.join(File.expand_path('../', __FILE__), 'support/*.rb')].each { |f| require f }

DatabaseCleaner.clean_with :truncation
DatabaseCleaner.strategy = :transaction
DatabaseCleaner.clean

RSpec.configure do |config|
  config.include(Rack::Test::Methods)
  config.include(Sinatra::Auth::Github::Test::Helper)

  def app
    Emerald::API::App.new
  end

  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    # be_bigger_than(2).and_smaller_than(4).description
    #   # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #   # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end
end

