module InteractorSupport
  ##
  # Custom error types surfaced by InteractorSupport helpers.
  module Errors
    class UnknownAttribute < StandardError
      attr_reader :attribute, :owner

      def initialize(attribute, owner: nil)
        @attribute = attribute
        @owner = owner
        super(build_message(attribute, owner))
      end

      private

      def build_message(attribute, owner)
        name =
          case attribute
          when String then attribute
          when Symbol then attribute.to_s
          else attribute.inspect
          end

        owner_name =
          if owner.respond_to?(:name) && owner.name
            owner.name
          elsif owner.respond_to?(:to_s)
            owner.to_s
          else
            owner
          end

        suffix = owner_name ? " for #{owner_name}" : ''
        "Unknown attribute: #{name}#{suffix}"
      end
    end

    class InvalidRequestObject < StandardError
      attr_reader :request_class, :errors

      def initialize(request_class:, errors: [])
        @request_class = request_class
        @errors = Array(errors)

        request_name =
          if request_class.respond_to?(:name) && request_class.name
            request_class.name
          else
            request_class.to_s
          end

        detail = @errors.any? ? ": #{@errors.join(", ")}" : ''

        super("Invalid #{request_name}#{detail}")
      end
    end
  end
end
