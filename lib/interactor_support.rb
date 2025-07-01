# frozen_string_literal: true

require 'interactor'
require 'logger'
require 'active_support/concern'
require 'interactor_support/errors'
require_relative 'interactor_support/core'
require_relative 'interactor_support/version'
require_relative 'interactor_support/actions'
require_relative 'interactor_support/validations'
require_relative 'interactor_support/request_object'
require_relative 'interactor_support/configuration'

Dir[File.join(__dir__, 'interactor_support/concerns/*.rb')].sort.each { |file| require file }

##
# InteractorSupport is a modular DSL for building expressive, validated, and
# transactional service objects using the [Interactor](https://github.com/collectiveidea/interactor) gem.
#
# It enhances interactors with powerful helpers like:
# - `Actions` for data loading, transformation, and persistence
# - `Validations` for context-aware presence/type/inclusion checks
# - `RequestObject` for clean, validated, form-like parameter objects
#
# It also provides configuration options to control request object behavior.
#
# @example Basic usage
#   class CreateUser
#     include Interactor
#     include InteractorSupport
#
#     required :email, :name
#
#     transform :email, with: [:strip, :downcase]
#
#     find_by :account
#
#     update :user, attributes: { email: :email, name: :name }
#   end
#
# @example Configuration
#   InteractorSupport.configure do |config|
#     config.request_object_behavior = :returns_self
#     config.request_object_key_type = :symbol
#   end
#
# @see InteractorSupport::Actions
# @see InteractorSupport::Validations
# @see InteractorSupport::RequestObject
# @see InteractorSupport::Configuration
module InteractorSupport
  extend ActiveSupport::Concern

  class << self
    ##
    # Allows external configuration of InteractorSupport.
    #
    # @yieldparam config [InteractorSupport::Configuration] the global configuration object
    # @return [void]
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    ##
    # Returns the global InteractorSupport configuration object.
    #
    # @return [InteractorSupport::Configuration]
    def configuration
      @configuration ||= Configuration.new
    end
  end

  included do
    include InteractorSupport::Actions
    include InteractorSupport::Validations
  end
end
