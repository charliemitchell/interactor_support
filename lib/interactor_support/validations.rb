require 'active_model'

module InteractorSupport
  ##
  # Provides a validation DSL tailored to interactor context.
  #
  # Including this module:
  # - Adds `ActiveModel::Validations`
  # - Introduces `required`, `optional`, `validates_before`, and `validates_after` helpers
  # - Automatically maps validated attributes to `context` accessors
  # - Halts execution with `context.fail!` when validations fail
  #
  # @example Required attributes with ActiveModel rules
  #   required :email, :name
  #   required age: { numericality: { greater_than: 18 } }
  #
  # @example Optional attributes with presence/format validations
  #   optional bio: { length: { maximum: 500 } }
  #
  # @example Type and inclusion validation before execution
  #   validates_before :role, type: String, inclusion: { in: %w[admin user guest] }
  #
  # @example Persistence validation after execution
  #   validates_after :user, persisted: true
  #
  # @see ActiveModel::Validations
  module Validations
    extend ActiveSupport::Concern
    include InteractorSupport::Core

    included do
      include ActiveModel::Validations
      include ActiveModel::Validations::Callbacks
    end

    class_methods do
      ##
      # Declares one or more attributes as required.
      #
      # Presence is enforced automatically, and any provided options are forwarded to
      # `ActiveModel::Validations#validates`.
      #
      # @param keys [Array<Symbol, Hash>] attribute names or hash of attributes with validation options
      def required(*keys)
        apply_validations(keys, required: true)
      end

      ##
      # Declares one or more attributes as optional.
      #
      # Optional values may be `nil` yet still participate in the provided validations.
      #
      # @param keys [Array<Symbol, Hash>] attribute names or hash of attributes with validation options
      def optional(*keys)
        apply_validations(keys, required: false)
      end

      ##
      # Runs additional validations *after* the interactor executes.
      #
      # Use this for checks that depend on side-effects inside `call` (e.g., persistence, background jobs).
      #
      # @param keys [Array<Symbol>] context keys to validate
      # @param validations [Hash] validation options (e.g., presence:, type:, inclusion:, persisted:)
      def validates_after(*keys, **validations)
        after do
          keys.each do |key|
            apply_custom_validations(key, validations)
          end
        end
      end

      ##
      # Runs validations *before* the interactor executes.
      #
      # Use this to guard business logic from invalid input. The `persisted:` check is only available in
      # {#validates_after} because it depends on side-effects.
      #
      # @param keys [Array<Symbol>] context keys to validate
      # @param validations [Hash] validation options (e.g., presence:, type:, inclusion:)
      def validates_before(*keys, **validations)
        before do
          if validations[:persisted]
            context.fail!(errors: ['persisted validation is only available for after validations'])
          end

          keys.each do |key|
            apply_custom_validations(key, validations)
          end
        end
      end

      private

      ##
      # Applies ActiveModel validations and wires up reader/writer methods to the context.
      #
      # @param keys [Array<Symbol, Hash>] attributes to validate
      # @param required [Boolean] whether presence is enforced
      def apply_validations(keys, required:)
        keys.each do |key|
          if key.is_a?(Hash)
            key.each do |attribute, validation_options|
              attr_accessor(attribute)

              define_context_methods(attribute)
              if required
                validates(attribute, validation_options)
              else
                validates(attribute, validation_options.merge(allow_nil: true))
              end
            end
          else
            attr_accessor(key)

            define_context_methods(key)
            validates(key, presence: true) if required
          end
        end

        before do
          context.fail!(errors: errors.full_messages) unless valid?
        end
      end

      ##
      # Defines methods to read/write from the interactor context.
      #
      # @param key [Symbol] the context key
      def define_context_methods(key)
        define_method(key) { context[key] }
        define_method("#{key}=") { |value| context[key] = value }
      end
    end

    ##
    # Applies custom inline validations to a context key.
    #
    # @param key [Symbol] the context key
    # @param validations [Hash] options like presence:, type:, inclusion:, persisted:
    def apply_custom_validations(key, validations)
      validation_for_presence(key) if validations[:presence]
      validation_for_inclusion(key, validations[:inclusion]) if validations[:inclusion]
      validation_for_persistence(key) if validations[:persisted]
      validation_for_type(key, validations[:type]) if validations[:type]
    end

    ##
    # Fails if context value is not of expected type.
    #
    # @param key [Symbol]
    # @param type [Class]
    def validation_for_type(key, type)
      context.fail!(errors: ["#{key} was not of type #{type}"]) unless context[key].is_a?(type)
    end

    ##
    # Fails if value is not included in allowed values.
    #
    # @param key [Symbol]
    # @param inclusion [Hash] with `:in` key
    def validation_for_inclusion(key, inclusion)
      unless inclusion.is_a?(Hash) && inclusion[:in].is_a?(Enumerable)
        raise ArgumentError, 'inclusion validation requires an :in key with an array or range'
      end

      context.fail!(errors: ["#{key} was not in the specified inclusion"]) unless inclusion[:in].include?(context[key])
    rescue ArgumentError => e
      context.fail!(errors: [e.message])
    end

    ##
    # Fails if value is nil or blank.
    #
    # @param key [Symbol]
    def validation_for_presence(key)
      context.fail!(errors: ["#{key} does not exist"]) unless context[key].present?
    end

    ##
    # Fails if value is not a persisted `ApplicationRecord`.
    #
    # @param key [Symbol]
    def validation_for_persistence(key)
      validation_for_presence(key)

      unless context[key].is_a?(ApplicationRecord)
        context.fail!(errors: ["#{key} is not an ApplicationRecord, which is required for persisted validation"])
      end

      context.fail!(errors: ["#{key} was not persisted"] + context[key].errors.full_messages) unless context[key].persisted?
    end
  end
end
