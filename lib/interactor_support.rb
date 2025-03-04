# frozen_string_literal: true

require 'active_support/concern'
require 'interactor_support'

require_relative 'interactor_support/version'
require_relative 'interactor_support/actions'
require_relative 'interactor_support/validations'
require_relative 'interactor_support/request_object'
Dir[File.join(__dir__, 'interactor_support/concerns/*.rb')].sort.each { |file| require file }

# Conditionally load RuboCop cops if RuboCop is installed
begin
  require 'rubocop'
  require_relative 'interactor_support/rubocop/cop/require_required_for_interactor_support'
rescue LoadError
  # RuboCop is not installed, so we don't load the cop
end

module InteractorSupport
  extend ActiveSupport::Concern
  included do
    include InteractorSupport::Actions
    include InteractorSupport::Validations
  end
end
