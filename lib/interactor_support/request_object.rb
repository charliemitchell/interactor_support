module InteractorSupport
  ##
  # A base module for building validated, transformable, and optionally nested request objects.
  #
  # It builds on top of `ActiveModel::Model`, adds coercion, default values, attribute transforms,
  # key rewriting, and automatic context conversion (via `#to_context`). It integrates tightly with
  # `InteractorSupport::Configuration` to control return behavior and key formatting.
  #
  # @example Basic usage
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
  # @example Key rewriting
  #   class UploadRequest
  #     include InteractorSupport::RequestObject
  #
  #     attribute :image, rewrite: :image_url
  #   end
  #
  #   UploadRequest.new(image: "url").image_url # => "url"
  #
  # @see InteractorSupport::Configuration
  module RequestObject
    extend ActiveSupport::Concern
    SUPPORTED_ACTIVEMODEL_TYPES = ActiveModel::Type.registry.send(:registrations).keys.map { |type| ":#{type}" }
    SUPPORTED_PRIMITIVES = ['AnyClass', 'Symbol', 'Hash', 'Array']
    SUPPORTED_TYPES = SUPPORTED_PRIMITIVES + SUPPORTED_ACTIVEMODEL_TYPES

    class TypeError < StandardError
    end

    included do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::AttributeAssignment
      include ActiveModel::Validations::Callbacks

      ##
      # Initializes the request object and raises if invalid.
      #
      # Rewritten keys are converted before passing to ActiveModel.
      #
      # @param attributes [Hash] the input attributes
      # @raise [ActiveModel::ValidationError] if the object is invalid
      def initialize(attributes = {})
        attributes = attributes.dup
        self.class.rewritten_attributes.each do |external, internal|
          if attributes.key?(external)
            attributes[internal] = attributes.delete(external)
          end
        end

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

      ##
      # Assigns the given attributes to the request object.
      #
      # - Known attributes are assigned normally via their setters.
      # - If `ignore_unknown_attributes?` is defined and true, unknown keys are ignored and logged.
      # - Otherwise, raises `Errors::UnknownAttribute`.
      #
      # @param attrs [Hash] input attributes to assign
      # @raise [Errors::UnknownAttribute] if unknown attribute is encountered and not ignored
      # @return [void]
      def assign_attributes(attrs)
        attrs.each do |k, v|
          setter = "#{k}="
          if respond_to?(setter)
            send(setter, v)
          elsif respond_to?(:ignore_unknown_attributes?) && ignore_unknown_attributes?
            InteractorSupport.configuration.logger.log(
              InteractorSupport.configuration.log_level,
              "InteractorSupport::RequestObject ignoring unknown attribute '#{k}' for #{self.class.name}.",
            )
          else
            raise Errors::UnknownAttribute, "`#{k}` for #{self.class.name}."
          end
        end
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
        # Defines whether to ignore unknown attributes during assignment.
        # If true, unknown attributes are logged but not raised as errors.
        # @example
        #   class MyRequest
        #     include InteractorSupport::RequestObject
        #     ignore_unknown_attributes
        #   end
        #   @return [void]
        def ignore_unknown_attributes
          define_method(:ignore_unknown_attributes?) { true }
        end

        ##
        # Defines one or more attributes with optional coercion, default values, transformation,
        # and an optional `rewrite:` key to rename the underlying attribute.
        #
        # @param names [Array<Symbol>] the attribute names
        # @param type [Class, nil] optional class to coerce the value to (often another request object)
        # @param array [Boolean] whether to treat the input as an array of typed objects
        # @param default [Object] default value if not provided
        # @param transform [Symbol, Array<Symbol>] method(s) to apply to the value
        # @param rewrite [Symbol, nil] optional internal name to rewrite this attribute to
        #
        # @raise [ArgumentError] if a transform method is not found
        def attribute(*names, type: nil, array: false, default: nil, transform: nil, rewrite: nil)
          names.each do |name|
            attr_name = rewrite || name
            rewritten_attributes[name.to_sym] = attr_name if rewrite
            transform_options[attr_name.to_sym] = transform if transform.present?

            super(attr_name, default: default)
            original_writer = instance_method("#{attr_name}=")

            define_method("#{attr_name}=") do |value|
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

              # If a `type` is specified, we attempt to cast the `value` to that type
              if type
                value = array ? Array(value).map { |v| cast_value(v, type) } : cast_value(value, type)
              end

              original_writer.bind(self).call(value)
            end
          end
        end

        ##
        # Internal map of external attribute names to internal rewritten names.
        #
        # @return [Hash{Symbol => Symbol}]
        def rewritten_attributes
          @_rewritten_attributes ||= {}
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

      private

      def cast_value(value, type)
        return typecast(value, type) if type.is_a?(Symbol)
        return value if value.is_a?(type)
        return type.new(value) if type <= InteractorSupport::RequestObject

        typecast(value, type)
      end

      def typecast(value, type)
        if type.is_a?(Symbol)
          ActiveModel::Type.lookup(type).cast(value)
        elsif type == Symbol
          value.to_sym
        elsif type == Array
          value.to_a
        elsif type == Hash
          value.to_h
        else
          raise TypeError
        end
      rescue ArgumentError
        message = ":#{type} is not a supported type. Supported types are: #{SUPPORTED_TYPES.join(", ")}"
        raise TypeError, message
      rescue
        raise TypeError, "Cannot cast #{value.inspect} to #{type.name}"
      end
    end
  end
end
