module InteractorSupport
  ##
  # Global configuration for InteractorSupport.
  #
  # This allows customization of how request objects behave when used in interactors.
  #
  # @example Set custom behavior
  #   InteractorSupport.configuration.request_object_behavior = :returns_self
  #   InteractorSupport.configuration.request_object_key_type = :struct
  #
  # @see InteractorSupport.configuration
  class Configuration
    ##
    # Defines how request objects behave when called.
    #
    # - `:returns_context` — The request object returns an Interactor-style context.
    # - `:returns_self` — The request object returns itself, allowing method chaining.
    #
    # @return [:returns_context, :returns_self]
    attr_accessor :request_object_behavior

    ##
    # Defines the key type used in request object context when `:returns_context` is active.
    #
    # - `:string` — Keys are string-based (`"name"`)
    # - `:symbol` — Keys are symbol-based (`:name`)
    # - `:struct` — Keys are accessed via struct-style method calls (`name`)
    #
    # @return [:string, :symbol, :struct]
    attr_accessor :request_object_key_type

    ##
    # Initializes the configuration with default values:
    # - `request_object_behavior` defaults to `:returns_context`
    # - `request_object_key_type` defaults to `:symbol`
    def initialize
      @request_object_behavior = :returns_context
      @request_object_key_type = :symbol
    end
  end
end
