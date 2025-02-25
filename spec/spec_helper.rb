# frozen_string_literal: true
require 'simplecov'
require 'simplecov-lcov'
SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter, # Generates HTML report
  SimpleCov::Formatter::LcovFormatter   # Generates LCOV report
])
SimpleCov.start do
  add_filter '/spec/' # Exclude spec files from coverage
  add_filter '/lib/interactor_support/version.rb' # Exclude config files from coverage
  track_files 'lib/**/*.rb' # Explicitly track lib files
end

require 'rails'
require 'active_record'
require "active_support"
require "interactor"
require "interactor_support"
require "byebug"

Dir[File.expand_path("../lib/*.rb", __FILE__)].sort.each { |f| require f }

# Load the Rails environment
ENV['RAILS_ENV'] ||= 'test'
ActiveRecord::Base.establish_connection(YAML.load_file(File.expand_path('database.yml', __dir__))['test'])

# Define ApplicationRecord if not already defined
unless defined?(ApplicationRecord)
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Clean up the database between tests
  config.before(:suite) do
    ActiveRecord::Migration.maintain_test_schema!
  end

  config.after(:each) do
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.execute("DELETE FROM #{table}") unless table == "schema_migrations"
    end
  end
end
