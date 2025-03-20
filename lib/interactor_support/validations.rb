require 'active_model'

module InteractorSupport
  module Validations
    extend ActiveSupport::Concern

    included do
      include ActiveModel::Validations
      include ActiveModel::Validations::Callbacks
    end

    class_methods do
      def required(*keys)
        apply_validations(keys, required: true)
      end

      def optional(*keys)
        apply_validations(keys, required: false)
      end

      def validates_after(*keys, **validations)
        after do
          keys.each do |key|
            apply_custom_validations(key, validations)
          end
        end
      end

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
        # Ensure validations run before execution
        before do
          context.fail!(errors: errors.full_messages) unless valid?
        end
      end

      def define_context_methods(key)
        define_method(key) { context[key] }
        define_method("#{key}=") { |value| context[key] = value }
      end
    end

    def apply_custom_validations(key, validations)
      validation_for_presence(key) if validations[:presence]
      validation_for_inclusion(key, validations[:inclusion]) if validations[:inclusion]
      validation_for_persistence(key) if validations[:persisted]
      validation_for_type(key, validations[:type]) if validations[:type]
    end

    def validation_for_type(key, type)
      context.fail!(errors: ["#{key} was not of type #{type}"]) unless context[key].is_a?(type)
    end

    def validation_for_inclusion(key, inclusion)
      unless inclusion.is_a?(Hash) && inclusion[:in].is_a?(Enumerable)
        raise ArgumentError, 'inclusion validation requires an :in key with an array or range'
      end

      context.fail!(errors: ["#{key} was not in the specified inclusion"]) unless inclusion[:in].include?(context[key])
    rescue ArgumentError => e
      context.fail!(errors: [e.message])
    end

    def validation_for_presence(key)
      context.fail!(errors: ["#{key} does not exist"]) unless context[key].present?
    end

    def validation_for_persistence(key)
      validation_for_presence(key)
      unless context[key].is_a?(ApplicationRecord)
        context.fail!(
          errors: [
            "#{key} is not an ApplicationRecord, which is required for persisted validation",
          ],
        )
      end

      context.fail!(
        errors: ["#{key} was not persisted"] + context[key].errors.full_messages,
      ) unless context[key].persisted?
    end
  end
end
