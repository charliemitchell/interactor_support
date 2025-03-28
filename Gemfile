# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in interactor_support.gemspec
gemspec

gem 'rake', '~> 13.0'

group :development, :test do
  gem 'interactor', '~> 3.0'
  gem 'rails', '~> 7.1', '>= 7.1'
  gem 'rspec', '~> 3.0'
  gem 'rubocop', '~> 1.21'
  gem 'rubocop-shopify', '~> 2.1', require: false
  gem 'sqlite3', '>= 2.1'
  gem 'byebug'
end

group :development do
  gem 'yard'
end

group :test do
  gem 'simplecov', require: false
  gem 'simplecov-lcov', require: false
end
