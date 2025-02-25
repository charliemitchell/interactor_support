require "active_model"

module InteractorSupport
  module Request
    extend ActiveSupport::Concern
    included do
      include ActiveModel::Validations

      class EmailValidator < ActiveModel::EachValidator
        def validate_each(record, attribute, value)
          record.errors.add(
            attribute,
            "is not an email",
          ) unless value.is_a?(String) && value =~ /\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/
        end
      end

      def initialize(*args)
        @attributes_key = "attributes"
        @attribute_keys = []
        super(*args)
      end

      def call
        context.fail!(errors: errors) unless valid?
        context[@attributes_key] = attributes
        super
      end

      def attributes
        @attribute_keys.each_with_object({}) do |key, hash|
          hash[key] = instance_variable_get("@#{key}")
        end
      end

      def self.attributes_key(key)
        before do
          instance_variable_set("@attributes_key", key)
        end
      end

      def self.param(*args, transform: [])
        before do
          @attribute_keys += args
          args.each do |arg|
            # If the value is nil, we don't want to transform it
            if context[arg].nil?
              instance_variable_set("@#{arg}", nil)
              self.class.send(:attr_reader, arg)
              next
            end

            raise ArgumentError, "Invalid transform argument" unless(
              transform.is_a?(Symbol) || 
              transform.is_a?(Array) || 
              transform.is_a?(Proc)
            )

            if transform.is_a?(Proc)
              begin
                instance_variable_set("@#{arg}", transform.call(context[arg]))
              rescue => e
                context.fail!(errors: ["#{arg} failed to transform: #{e.message}"])
              end
            elsif transform.empty?
              instance_variable_set("@#{arg}", context[arg])
            elsif transform.is_a?(Array) && transform.all? { |t| t.is_a?(Symbol) && context[arg].respond_to?(t) }
              instance_variable_set("@#{arg}", transform(context[arg], transform))
            elsif transform.is_a?(Array)
              context.fail!(errors: ["#{arg} does not respond to all transforms"])
            elsif transform.is_a?(Symbol) && context[arg].respond_to?(transform)
              instance_variable_set("@#{arg}", context[arg].send(transform))
            elsif transform.is_a?(Symbol)
              context.fail!(errors: ["#{arg} does not respond to the given transform"])
            end

            self.class.send(:attr_reader, arg)
          end
        end
      end

      private

      def transform(value, transforms)
        transforms.reduce(value) do |memo, transform|
          memo.send(transform)
        end
      end
    end
  end
end
