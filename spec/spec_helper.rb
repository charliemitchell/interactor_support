# frozen_string_literal: true

##
# Test suite setup for InteractorSupport.
# Includes:
# - SimpleCov + LCOV for test coverage
# - ActiveRecord in-memory config
# - RSpec configuration and lifecycle hooks
# - Loads support files and test models

# ---------------------
# Coverage Configuration
# ---------------------

require 'simplecov'
require 'simplecov-lcov'

SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::LcovFormatter,
])

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/lib/interactor_support/version.rb'
  add_filter '/lib/interactor_support/rubocop/'
  add_filter '/lib/interactor_support/rubocop.rb'
  track_files 'lib/**/*.rb'
end

# ---------------------
# Runtime Dependencies
# ---------------------

require 'rails'
require 'active_record'
require 'active_support'
require 'interactor'
require 'interactor_support'
require 'byebug'

# Load local lib files if present
Dir[File.expand_path('../lib/*.rb', __FILE__)].sort.each { |f| require f }

# ------------------------
# ActiveRecord Setup (Test)
# ------------------------

ENV['RAILS_ENV'] ||= 'test'

ActiveRecord::Base.establish_connection(
  YAML.load_file(File.expand_path('database.yml', __dir__))['test'],
)

# Define ApplicationRecord unless defined (Rails-style base model)
unless defined?(ApplicationRecord)
  ##
  # Abstract base class for test models
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end

# Load support files
Dir[File.expand_path('support/**/*.rb', __dir__)].sort.each { |f| require f }

# -----------------
# RSpec Configuration
# -----------------

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!

  config.expect_with(:rspec) do |c|
    c.syntax = :expect
  end

  # Clean database before and after test suite runs
  config.before(:suite) do
    ActiveRecord::Migration.maintain_test_schema!
  end

  config.after(:each) do
    ActiveRecord::Base.connection.tables.each do |table|
      next if table == 'schema_migrations'

      ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
    end
  end
end
