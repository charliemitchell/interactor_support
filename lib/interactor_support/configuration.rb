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
    # Logger for InteractorSupport, defaults to STDOUT.
    # @return [Logger]
    attr_accessor :logger

    ##
    # The log level for InteractorSupport logs.
    # @return [Integer]
    attr_accessor :log_level

    ##
    # Whether to log unknown request object attributes when they are ignored.
    # If true, logs a warning when an unknown attribute is encountered.
    # @see InteractorSupport::RequestObject#ignore_unknown_attributes
    attr_accessor :log_unknown_request_object_attributes

    ##
    # Initializes the configuration with default values:
    # - `request_object_behavior` defaults to `:returns_context`
    # - `request_object_key_type` defaults to `:symbol`
    # - `logger` defaults to a new Logger instance writing to STDOUT
    # - `log_level` defaults to `Logger::INFO`
    # - `log_unknown_request_object_attributes` defaults to `true`
    def initialize
      @request_object_behavior = :returns_context
      @request_object_key_type = :symbol
      @logger = Logger.new($stdout)
      @log_level = Logger::INFO
      @log_unknown_request_object_attributes = true
    end
  end
end
