# lib/interactor_support/request_object.rb
module InteractorSupport
  ##
  # A base module for building validated, transformable, and optionally nested request objects.
  #
  # It builds on top of `ActiveModel::Model`, adds coercion, default values, attribute transforms,
  # and automatic context conversion (via `#to_context`). It integrates tightly with
  # `InteractorSupport::Configuration` to control return behavior and key formatting.
  #
  # @example Simple usage
  #   class CreateUserRequest
  #     include InteractorSupport::RequestObject
  #
  #     attribute :name, transform: [:strip, :downcase]
  #     attribute :email
  #     attribute :metadata, default: {}
  #   end
  #
  #   CreateUserRequest.new(name: " JOHN ", email: "hi@example.com")
  #   # => { name: "john", email: "hi@example.com", metadata: {} }
  #
  # @see InteractorSupport::Configuration
  module RequestObject
    extend ActiveSupport::Concern

    included do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Validations::Callbacks

      ##
      # Initializes the request object and raises if invalid.
      #
      # @param attributes [Hash] the input attributes
      # @raise [ActiveModel::ValidationError] if the object is invalid
      def initialize(attributes = {})
        super(attributes)
        raise ActiveModel::ValidationError, self unless valid?
      end

      ##
      # Converts the request object into a format suitable for interactor context.
      #
      # - If `key_type` is `:symbol` or `:string`, returns a Hash.
      # - If `key_type` is `:struct`, returns a Struct instance.
      #
      # Nested request objects will also be converted recursively.
      #
      # @return [Hash, Struct]
      def to_context
        key_type = InteractorSupport.configuration.request_object_key_type
        attrs = attributes.each_with_object({}) do |(name, value), hash|
          name = key_type == :string ? name.to_s : name.to_sym
          hash[name] = if value.respond_to?(:to_context)
            value.to_context
          elsif value.is_a?(Array) && value.first.respond_to?(:to_context)
            value.map(&:to_context)
          else
            value
          end
        end
        return Struct.new(*attrs.keys).new(*attrs.values) if key_type == :struct

        attrs
      end

      class << self
        ##
        # Custom constructor that optionally returns the context instead of the object itself.
        #
        # Behavior is configured via `InteractorSupport.configuration.request_object_behavior`.
        #
        # @param args [Array] positional args
        # @param kwargs [Hash] keyword args
        # @return [RequestObject, Hash, Struct]
        def new(*args, **kwargs)
          return super(*args, **kwargs) if InteractorSupport.configuration.request_object_behavior == :returns_self

          super(*args, **kwargs).to_context
        end

        ##
        # Defines one or more attributes with optional coercion, default values, and transformation.
        #
        # @param names [Array<Symbol>] the attribute names
        # @param type [Class, nil] optional class to coerce the value to (often another request object)
        # @param array [Boolean] whether to treat the input as an array of typed objects
        # @param default [Object] default value if not provided
        # @param transform [Symbol, Array<Symbol>] method(s) to apply to the value
        #
        # @raise [ArgumentError] if a transform method is not found
        #
        # @example Basic with type coercion and transformation
        #   attribute :name, transform: [:strip, :downcase]
        #
        # @example Nested request object
        #   attribute :address, type: AddressRequest
        #
        # @example Array of nested request objects
        #   attribute :items, type: ItemRequest, array: true
        def attribute(*names, type: nil, array: false, default: nil, transform: nil)
          names.each do |name|
            transform_options[name.to_sym] = transform if transform.present?
            super(name, default: default)
            original_writer = instance_method("#{name}=")

            define_method("#{name}=") do |value|
              # Apply transforms
              if transform
                Array(transform).each do |method|
                  if value.respond_to?(method)
                    value = value.send(method)
                  elsif respond_to?(method)
                    value = send(method, value)
                  else
                    raise ArgumentError, "transform method #{method} not found"
                  end
                end
              end

              # Type coercion
              if type
                value = if array
                  Array(value).map { |v| v.is_a?(type) ? v : type.new(v) }
                else
                  value.is_a?(type) ? value : type.new(value)
                end
              end

              original_writer.bind(self).call(value)
            end
          end
        end

        private

        ##
        # Internal storage for transform options per attribute.
        #
        # @return [Hash{Symbol => Symbol, Array<Symbol>}]
        def transform_options
          @_transform_options ||= {}
        end
      end
    end
  end
end
