module InteractorSupport
  class Configuration
    attr_accessor :request_object_behavior, :request_object_key_type

    def initialize
      # Default configuration values.
      # :returns_context - request objects return a context object.
      # :returns_self - request objects return self.
      @request_object_behavior = :returns_context

      # Default configuration values, only applies when request_object_behavior is :returns_context.
      # :string - request object keys are strings.
      # :symbol - request object keys are symbols.
      # :struct - request object keys are struct objects.
      @request_object_key_type = :symbol
    end
  end
end
