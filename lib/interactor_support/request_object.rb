module InteractorSupport
  ##
  # Provides a concise DSL for building validated, transformable, and nested request objects.
  #
  # Including this module gives you:
  # - ActiveModel validations and callbacks
  # - Attribute coercion (via ActiveModel types or custom classes/request objects)
  # - Value transforms, defaults, and key rewriting
  # - A `#to_context` helper that converts the object into hashes or structs for interactors
  # - Predictable error handling (unknown attributes raise {Errors::UnknownAttribute},
  #   invalid records raise {ActiveModel::ValidationError})
  #
  # Configure return semantics (hash vs. struct vs. self) through {InteractorSupport::Configuration}.
  #
  # @example Basic usage
  #   class CreateUserRequest
  #     include InteractorSupport::RequestObject
  #
  #     attribute :name, transform: [:strip, :downcase]
  #     attribute :email
  #     attribute :metadata, default: {}
  #
  #     validates :email, presence: true
  #   end
  #
  #   CreateUserRequest.new(name: " JOHN ", email: "hi@example.com")
  #   # => { name: "john", email: "hi@example.com", metadata: {} }
  #
  # @example Key rewriting and nested objects
  #   class UploadRequest
  #     include InteractorSupport::RequestObject
  #
  #     attribute :image, rewrite: :image_url
  #     attribute :metadata, type: ImageMetadataRequest
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
      # Initializes the request object, applying key rewrites and validations.
      #
      # Unknown keys trigger {Errors::UnknownAttribute} (unless `ignore_unknown_attributes` is enabled).
      # Validation failures raise `ActiveModel::ValidationError`, which is wrapped by
      # {InteractorSupport::Concerns::Organizable#organize organize} when used through organizers.
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
      # Converts the request object into the structure expected by interactors.
      #
      # - If `request_object_key_type` is `:symbol` or `:string`, returns a Hash keyed accordingly.
      # - If `request_object_key_type` is `:struct`, returns a Struct with attribute readers.
      #
      # Nested request objects (including arrays of request objects) are converted recursively.
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
      # Assigns external attributes, respecting rewrite rules and the unknown-attribute policy.
      #
      # - Known attributes are routed through generated setters so transforms and type coercion run.
      # - If `ignore_unknown_attributes` was declared, unrecognized keys are ignored (and optionally logged).
      # - Otherwise {Errors::UnknownAttribute} is raised with the offending key and request class.
      #
      # @param attrs [Hash] input attributes to assign
      # @raise [Errors::UnknownAttribute] if an unknown attribute is encountered and not ignored
      # @return [void]
      def assign_attributes(attrs)
        attrs.each do |k, v|
          setter = "#{k}="
          if respond_to?(setter)
            send(setter, v)
          elsif respond_to?(:ignore_unknown_attributes?) && ignore_unknown_attributes?
            if InteractorSupport.configuration.log_unknown_request_object_attributes
              InteractorSupport.configuration.logger.log(
                InteractorSupport.configuration.log_level,
                "InteractorSupport::RequestObject ignoring unknown attribute '#{k}' for #{self.class.name}.",
              )
            end
          else
            raise Errors::UnknownAttribute.new(k, owner: self.class)
          end
        end
      end

      class << self
        ##
        # Custom constructor with pluggable return behavior.
        #
        # Controlled by `InteractorSupport.configuration.request_object_behavior`:
        # - `:returns_self` returns the request object instance (good for explicit `#valid?` checks).
        # - `:returns_context` (default) immediately calls {#to_context} for interactor-style hashes/structs.
        #
        # @param args [Array] positional args
        # @param kwargs [Hash] keyword args
        # @return [RequestObject, Hash, Struct]
        def new(*args, **kwargs)
          return super(*args, **kwargs) if InteractorSupport.configuration.request_object_behavior == :returns_self

          super(*args, **kwargs).to_context
        end

        ##
        # Declares that unknown attributes should be ignored instead of raising.
        #
        # Ignored keys can still be logged (controlled via
        # `InteractorSupport.configuration.log_unknown_request_object_attributes`).
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
        # Declares one or more attributes with optional coercion, defaults, transforms, and key rewrites.
        #
        # @param names [Array<Symbol>] the attribute names declared on the public API
        # @param type [Class, Symbol, nil] optional coercion target (ActiveModel symbol or another request object)
        # @param array [Boolean] treat input as an array of typed objects and coerce each element
        # @param default [Object] default value if not provided by the caller
        # @param transform [Symbol, Array<Symbol>, Proc] one or more transformations applied before coercion
        # @param rewrite [Symbol, nil] internal name to assign stored value to (useful for renaming keys)
        #
        # @raise [ArgumentError] if a transform method cannot be resolved
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

              # If a `type` is specified, cast the value to the configured type before assignment.
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
        type_name =
          if type.respond_to?(:name) && type.name
            type.name
          else
            type.to_s
          end
        raise TypeError, "Cannot cast #{value.inspect} to #{type_name}"
      end
    end
  end
end
