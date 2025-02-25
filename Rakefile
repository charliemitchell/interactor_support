# filepath: ./Rakefile
# frozen_string_literal: true

require "bundler/gem_tasks"
require "rails"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require 'active_record'
require 'rake'
require 'yaml'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

# Load the Rails environment
ENV['RAILS_ENV'] ||= 'test'
db_config = YAML.load_file(File.expand_path('spec/database.yml', __dir__))
ActiveRecord::Base.configurations = db_config
ActiveRecord::Base.establish_connection(:test)

# Define the migration directory
ActiveRecord::Tasks::DatabaseTasks.migrations_paths = [File.expand_path('spec/migrations', __dir__)]

# Load the ActiveRecord tasks manually
namespace :db do
  desc "Migrate the database"
  task :migrate do
    ActiveRecord::Migrator.migrations_paths = ActiveRecord::Tasks::DatabaseTasks.migrations_paths
    ActiveRecord::MigrationContext.new(ActiveRecord::Migrator.migrations_paths).migrate
  end

  desc "Create the database"
  task :create do
    ActiveRecord::Tasks::DatabaseTasks.create_current
  end

  desc "Drop the database"
  task :drop do
    ActiveRecord::Tasks::DatabaseTasks.drop_current
  end

  desc "Reset the database"
  task :reset => [:drop, :create, :migrate]
end

# Load the Rake tasks
Rake::Task.define_task(:environment) do
  ActiveRecord::Base.establish_connection(:test)
end