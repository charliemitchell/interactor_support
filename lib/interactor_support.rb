# frozen_string_literal: true

require 'logger'
require 'rails'
require 'interactor'
require 'active_support/concern'
require_relative 'interactor_support/core'
require_relative 'interactor_support/version'
require_relative 'interactor_support/actions'
require_relative 'interactor_support/validations'
require_relative 'interactor_support/request_object'
require_relative 'interactor_support/configuration'

Dir[File.join(__dir__, 'interactor_support/concerns/*.rb')].sort.each { |file| require file }

module InteractorSupport
  extend ActiveSupport::Concern

  class << self
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    def configuration
      @configuration ||= Configuration.new
    end
  end

  included do
    include InteractorSupport::Actions
    include InteractorSupport::Validations
  end
end
