# app/concerns/interactor_support/request_object.rb
module InteractorSupport
  module RequestObject
    extend ActiveSupport::Concern

    included do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Validations::Callbacks

      # before_validation :apply_transforms

      def initialize(attributes = {})
        super(attributes)
        raise ActiveModel::ValidationError, self unless valid?
      end

      class << self
        # Accepts one or more attribute names along with options.
        #
        # Options:
        #   - type: a class to cast the value (often another RequestObject)
        #   - array: when true, expects an array; each element is cast.
        #   - default: default value for the attribute.
        #   - transform: a symbol or an array of symbols that will be applied (if the value responds to them).
        def attribute(*names, type: nil, array: false, default: nil, transform: nil)
          names.each do |name|
            transform_options[name.to_sym] = transform if transform.present?
            super(name, default: default)
            original_writer = instance_method("#{name}=")
            define_method("#{name}=") do |value|
              # Apply transforms immediately if provided.
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
              # Type: only wrap if not already an instance.
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

        def transform_options
          @_transform_options ||= {}
        end
      end
    end
  end
end
