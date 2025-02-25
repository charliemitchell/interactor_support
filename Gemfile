# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in interactor_support.gemspec
gemspec

gem "rake", "~> 13.0"

group :development, :test do
  gem "rspec", "~> 3.0"
  gem "rubocop", "~> 1.21"
  gem "rails"
  gem "sqlite3", ">= 2.1"
  gem "interactor", "~> 3.0"
  gem "byebug"
end

group :test do
  gem 'simplecov', require: false
  gem 'simplecov-lcov', require: false
end
