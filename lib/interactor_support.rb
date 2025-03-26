# frozen_string_literal: true

require 'logger'
require 'interactor'
require 'active_support/concern'
require_relative 'interactor_support/version'

module InteractorSupport
  extend ActiveSupport::Concern

  autoload :Core,            'interactor_support/core'
  autoload :Actions,         'interactor_support/actions'
  autoload :Validations,     'interactor_support/validations'
  autoload :RequestObject,   'interactor_support/request_object'
  autoload :Configuration,   'interactor_support/configuration'

  module Concerns
  end

  Dir[File.join(__dir__, 'interactor_support/concerns/*.rb')].sort.each do |file|
    filename = File.basename(file, '.rb')
    autoload filename.camelize.to_sym, "interactor_support/concerns/#{filename}"
  end

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
