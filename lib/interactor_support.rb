# frozen_string_literal: true

require 'active_support/concern'
require 'interactor_support'

require_relative 'interactor_support/version'
require_relative 'interactor_support/actions'
require_relative 'interactor_support/validations'
require_relative 'interactor_support/request_object'
Dir[File.join(__dir__, 'interactor_support/concerns/*.rb')].sort.each { |file| require file }

module InteractorSupport
  extend ActiveSupport::Concern
  included do
    include InteractorSupport::Actions
    include InteractorSupport::Validations
  end
end
