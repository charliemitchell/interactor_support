require 'active_model'

module InteractorSupport
  module Validations
    extend ActiveSupport::Concern

    included do
      include ActiveModel::Validations
      include ActiveModel::Validations::Callbacks

      class << self
        def optional(*keys)
          context_accessor(*keys)
        end

        def validates_after(*keys, **validations)
          after do
            keys.each do |key|
              validation_for_presence(key) if validations[:presence]
              validation_for_inclusion(key, validations[:inclusion]) if validations[:inclusion]
              validation_for_persistence(key) if validations[:persisted]
              validation_for_type(key, validations[:type]) if validations[:type]
            end
          end
        end

        def validates_before(*keys, **validations)
          before do
            context.fail!(errors: ['persisted validation is only available for after validations']) if validations[:persisted]

            keys.each do |key|
              validation_for_presence(key) if validations[:presence]
              validation_for_inclusion(key, validations[:inclusion]) if validations[:inclusion]
              validation_for_type(key, validations[:type]) if validations[:type]
            end
          end
        end

        # Define context accessors dynamically
        def context_accessor(*keys)
          keys.each do |key|
            attr_accessor(key)

            define_method(key) { context[key] }
            define_method("#{key}=") { |value| context[key] = value }
          end
        end

        def required(*keys)
          keys.each do |key|
            attr_accessor(key)

            define_method(key) { context[key] }
            define_method("#{key}=") { |value| context[key] = value }
          end

          before do
            missing_keys = keys - context.to_h.keys
            context.fail!(errors: missing_keys.map { |key| "#{key} is required" }) if missing_keys.any?
          end
        end
      end
    end

    private

    def validation_for_type(key, type)
      context.fail!(errors: ["#{key} was not of type #{type}"]) unless context[key].is_a?(type)
    end

    def validation_for_inclusion(key, inclusion)
      raise ArgumentError, 'inclusion validation requires an inclusion hash' unless inclusion.is_a?(Hash)
      raise ArgumentError, 'inclusion validation requires an :in key' unless inclusion[:in].present?

      raise ArgumentError,
'inclusion validation requires an array or range of values' unless inclusion[:in].is_a?(Array) || inclusion[:in].is_a?(Range)

      context.fail!(errors: ["#{key} was not in the specified inclusion"]) unless inclusion[:in].include?(context[key])
    rescue ArgumentError => e
      context.fail!(errors: [e.message])
    end

    def validation_for_presence(key)
      context.fail!(errors: ["#{key} does not exist"]) unless context[key].present?
    end

    def validation_for_persistence(key)
      validation_for_presence(key)
      raise ArgumentError,
      'persisted validation requires the context key to be a model' unless context[key].is_a?(ApplicationRecord)

      context.fail!(errors: ["#{key} was not persisted"] + context[key].errors.full_messages) unless context[key].persisted?
    end
  end
end
