# frozen_string_literal: true

module InteractorSupport
  module Concerns
    ##
    # Utilities for invoking interactors with request objects and shaping incoming params.
    #
    # Include this concern in controllers or service entry points to:
    # - Allowlist and transform request parameters in a single place
    # - Build request objects and pass them to interactors with one call
    # - Receive consistent `InvalidRequestObject` errors when validation fails
    # - Register reusable failure handlers with {#handle_interactor_failure}
    #
    # @example Include in a controller
    #   class ApplicationController < ActionController::Base
    #     include InteractorSupport::Organizable
    #   end
    #
    # @see InteractorSupport::Concerns::Organizable#organize
    # @see InteractorSupport::Concerns::Organizable#request_params
    # @see InteractorSupport::Concerns::Organizable.handle_interactor_failure
    module Organizable
      include ActiveSupport::Concern

      FailureHandledSignal = Class.new(StandardError) do
        attr_reader :failure

        def initialize(failure)
          @failure = failure
          super('Interactor failure handled')
        end
      end

      FailurePayload = Struct.new(
        :context,
        :error,
        :interactor,
        :request_object,
        :params,
        :controller,
        keyword_init: true,
      ) do
        def handled!
          @handled = true
        end

        def handled?
          !!@handled
        end

        def errors
          if error.respond_to?(:errors) && error.errors.present?
            error.errors
          elsif context.respond_to?(:errors) && context.errors.present?
            context.errors
          elsif error.respond_to?(:message)
            Array(error.message).compact
          else
            []
          end
        end

        def status
          if error.respond_to?(:status)
            error.status
          elsif context.respond_to?(:status)
            context.status
          end
        end

        def to_h
          {
            context: context,
            error: error,
            interactor: interactor,
            request_object: request_object,
            params: params,
            handled: handled?,
          }
        end
      end

      ErrorHandlerDefinition = Struct.new(:callable, :only, :except, keyword_init: true) do
        def applicable?(action_name)
          action = action_name&.to_sym
          return false if only.any? && action && !only.include?(action)
          return false if except.any? && action && except.include?(action)

          true
        end
      end

      def self.included(base)
        super

        base.extend(ClassMethods)

        if base.respond_to?(:rescue_from)
          base.rescue_from(FailureHandledSignal) do |_signal|
            # Handled responses are already rendered by the registered handler.
          end
        end
      end

      module ClassMethods
        ##
        # Registers a failure handler that runs when an interactor fails.
        #
        # Handlers execute in declaration order. Use `only:` and `except:` to scope execution
        # to specific actions (mirroring Rails filters). A handler may be a method name,
        # Proc, or any callable responding to `#call`.
        #
        # Returning a truthy value or calling `failure.handled!` marks the failure as handled.
        #
        # @param handler [Symbol, Proc, #call] the handler to invoke
        # @param only [Array<Symbol>, Symbol, nil] optional list of actions to run on
        # @param except [Array<Symbol>, Symbol, nil] optional list of actions to skip
        # @return [void]
        def handle_interactor_failure(handler, only: nil, except: nil)
          definition = ErrorHandlerDefinition.new(
            callable: handler,
            only: Array(only).compact.map(&:to_sym),
            except: Array(except).compact.map(&:to_sym),
          )

          definitions = interactor_failure_handler_definitions + [definition]
          @_interactor_failure_handler_definitions = definitions.freeze
        end

        def interactor_failure_handler_definitions
          @_interactor_failure_handler_definitions ||= []
        end

        def reset_interactor_failure_handlers!
          @_interactor_failure_handler_definitions = [].freeze
        end
      end

      # Calls the given interactor with a request object derived from `params`.
      #
      # - If `context_key` is provided, the request is namespaced under that key when invoking `call`.
      # - Validation failures raise {InteractorSupport::Errors::InvalidRequestObject}, allowing the caller
      #   to rescue and render validation messages without inspecting ActiveModel internals.
      #
      # @param interactor [Class] The interactor class or organizer to call.
      # @param params [Hash] Raw parameters to initialize the request object.
      # @param request_object [Class] A request object class that responds to `.new`.
      # @param context_key [Symbol, nil] Optional key to assign the request object under in the context.
      # @param error_handler [Symbol, Proc, Array<Symbol,Proc>, false, nil] Override the registered failure handlers.
      #   Use `false` to skip handlers, or include `:defaults` inside the array to inject class/config handlers.
      # @param halt_on_handle [Boolean] When true (default), a handled failure halts the caller via an internal signal.
      #
      # @return [Interactor::Context]
      #
      # @example Basic call
      #   organize(Users::Create, params: request_params(:user), request_object: CreateUserRequest)
      #
      # @example Namespace the request in context
      #   organize(Users::Create,
      #            params: request_params(:user),
      #            request_object: CreateUserRequest,
      #            context_key: :request)
      def organize(interactor, params:, request_object:, context_key: nil, error_handler: nil, halt_on_handle: true)
        @_interactor_failure_handled = false
        @context = nil

        handlers = resolve_error_handlers(error_handler)

        request_payload = build_request_payload(
          interactor: interactor,
          request_object: request_object,
          params: params,
          handlers: handlers,
          halt_on_handle: halt_on_handle,
        )

        return @context if interactor_failure_handled?

        payload = context_key ? { context_key => request_payload } : request_payload

        @context = invoke_interactor(interactor, payload, handlers, request_object, params, halt_on_handle)

        if failure_context?(@context)
          failure = dispatch_interactor_failure_handlers(
            handlers: handlers,
            context: @context,
            error: extract_context_error(@context),
            interactor: interactor,
            request_object: request_object,
            params: params,
          )

          emit_failure_signal_if_needed(failure, halt_on_handle)
        end

        @context
      end

      ##
      # Indicates whether the most recent `organize` call routed a failure through a handler.
      # Useful when you pass `halt_on_handle: false` and want to branch manually.
      #
      # @return [Boolean]
      def interactor_failure_handled?
        !!@_interactor_failure_handled
      end

      # Builds a structured parameter hash from Rails' `params`, with helpers for rewriting keys.
      #
      # Use this as the single entry point for shaping incoming parameters before they are given to
      # request objects. It combines extraction, filtering, renaming, flattening, defaults, and merges
      # in a single call.
      #
      # @param top_level_keys [Array<Symbol>] Top-level keys to extract from `params`. If empty, all keys are included.
      # @param merge [Hash] Additional values to merge into the final result.
      # @param except [Array<Symbol, Array<Symbol>>] Keys or nested key paths to exclude from the result.
      # @param rewrite [Array<Hash>] A set of transformation rules applied to the top-level keys.
      #
      # @return [Hash] The shaped parameters hash ready for request object initialization.
      #
      # @example Extracting a specific top-level key
      #   # Given: params = { order: { product_id: 1, quantity: 2 } }
      #   request_params(:order)
      #   # => { order: { product_id: 1, quantity: 2 } }
      #
      # @example Without top-level keys (includes all)
      #   # Given: params = { order: { product_id: 1 }, app_id: 123 }
      #   request_params()
      #   # => { order: { product_id: 1 }, app_id: 123 }
      #
      # @example Merging and excluding
      #   # Given: params = { order: { product_id: 1, quantity: 2 }, internal: "yes" }
      #   request_params(:order, merge: { user_id: 123 }, except: [[:order, :quantity], :internal])
      #   # => { order: { product_id: 1 }, user_id: 123 }
      #
      # @example Flattening a nested hash into the top-level
      #   # Given: params = { order: { product_id: 1, quantity: 2 }, app_id: 123 }
      #   request_params(:order, rewrite: [{ order: { flatten: true } }])
      #   # => { product_id: 1, quantity: 2 }
      #
      # @example Rename a top-level key and filter nested keys
      #   # Given: params = { metadata: { source: "mobile", internal: "x" } }
      #   request_params(:metadata, rewrite: [
      #     { metadata: { as: :meta, only: [:source] } }
      #   ])
      #   # => { meta: { source: "mobile" } }
      #
      # @example Provide a default value if a key is missing
      #   # Given: params = {}
      #   request_params(:session, rewrite: [
      #     { session: { default: { id: nil } } }
      #   ])
      #   # => { session: { id: nil } }
      #
      # @example Merge values into a nested structure
      #   # Given: params = { flags: { foo: true } }
      #   request_params(:flags, rewrite: [
      #     { flags: { merge: { debug: true } } }
      #   ])
      #   # => { flags: { foo: true, debug: true } }
      #
      # @example Combine multiple rewrite rules
      #   # Given:
      #   # params = {
      #   #   order: { product_id: 1, quantity: 2 },
      #   #   metadata: { source: "mobile", location: { ip: "1.2.3.4" } },
      #   #   tracking: { click_id: "abc", session_id: "def" }
      #   # }
      #   request_params(:order, :metadata, :tracking, rewrite: [
      #     { order: { flatten: true } },
      #     { metadata: { as: :meta, only: [:source, :location], flatten: [:location] } }
      #   ])
      #   # => {
      #   #   product_id: 1,
      #   #   quantity: 2,
      #   #   meta: { source: "mobile", ip: "1.2.3.4" },
      #   #   tracking: { click_id: "abc", session_id: "def" }
      #   # }
      def request_params(*top_level_keys, merge: {}, except: [], rewrite: [])
        permitted = params.permit!.to_h.deep_symbolize_keys
        data = top_level_keys.any? ? permitted.slice(*top_level_keys) : permitted

        apply_rewrites!(data, rewrite)

        data
          .deep_merge(merge)
          .then { |result| except.any? ? deep_except(result, except) : result }
      end

      private

      def apply_rewrites!(data, rewrites)
        rewrites.each do |rule|
          key, config = rule.first
          config = { flatten: true } if config == :flatten

          original = data.key?(key) ? data.delete(key) : nil
          transformed = original.deep_dup if original.is_a?(Hash)
          transformed ||= original

          # Filtering
          transformed.slice!(*config[:only]) if config[:only] && transformed.respond_to?(:slice!)
          transformed.except!(*config[:except]) if config[:except] && transformed.respond_to?(:except!)

          # Flatten specific nested keys
          if config[:flatten].is_a?(Array) && transformed.is_a?(Hash)
            config[:flatten].each do |subkey|
              nested = transformed.delete(subkey)
              if nested.is_a?(Hash)
                transformed.merge!(nested)
              elsif nested.is_a?(Array)
                raise ArgumentError,
                  "Cannot flatten array for the key `#{subkey}`. Flattening arrays of hashes is not supported."
              end
            end
          end

          # Apply default if nil or missing
          transformed ||= config[:default]

          # Merge additional keys
          if config[:merge]
            transformed = transformed.is_a?(Hash) ? transformed.merge(config[:merge]) : config[:merge]
          end

          # Fully flatten to top level
          if config[:flatten] == true && transformed.is_a?(Hash)
            data.merge!(transformed)
          else
            target_key = config[:as] || key
            data[target_key] = transformed
          end
        end
      end

      def deep_except(hash, paths)
        paths.reduce(hash) { |acc, path| remove_nested_key(acc, Array(path)) }
      end

      def remove_nested_key(hash, path)
        return hash unless path.is_a?(Array) && path.any?

        key, *rest = path
        return hash unless hash.key?(key)

        duped = hash.dup
        if rest.empty?
          duped.delete(key)
        elsif duped[key].is_a?(Hash)
          duped[key] = remove_nested_key(duped[key], rest)
        end

        duped
      end

      def build_request_payload(interactor:, request_object:, params:, handlers:, halt_on_handle:)
        request_object.new(params)
      rescue ActiveModel::ValidationError => e
        invalid_error = InteractorSupport::Errors::InvalidRequestObject.new(
          request_class: request_object,
          errors: extract_active_model_errors(e),
        )

        failure = dispatch_interactor_failure_handlers(
          handlers: handlers,
          context: nil,
          error: invalid_error,
          interactor: interactor,
          request_object: request_object,
          params: params,
        )

        emit_failure_signal_if_needed(failure, halt_on_handle)

        raise invalid_error unless failure.handled?

        @context
      rescue FailureHandledSignal
        raise
      rescue StandardError => e
        failure = dispatch_interactor_failure_handlers(
          handlers: handlers,
          context: nil,
          error: e,
          interactor: interactor,
          request_object: request_object,
          params: params,
        )

        emit_failure_signal_if_needed(failure, halt_on_handle)

        raise e unless failure.handled?

        @context
      end

      def invoke_interactor(interactor, payload, handlers, request_object, params, halt_on_handle)
        context = interactor.call(payload)
        @context = context
        context
      rescue FailureHandledSignal
        raise
      rescue StandardError => e
        failure = dispatch_interactor_failure_handlers(
          handlers: handlers,
          context: nil,
          error: e,
          interactor: interactor,
          request_object: request_object,
          params: params,
        )

        emit_failure_signal_if_needed(failure, halt_on_handle)

        raise e unless failure.handled?

        @context
      end

      def extract_active_model_errors(exception)
        if exception.model&.respond_to?(:errors)
          exception.model.errors.full_messages
        else
          []
        end
      end

      def extract_context_error(context)
        if context.respond_to?(:error)
          context.error
        elsif context.respond_to?(:errors) && context.errors.respond_to?(:full_messages)
          context.errors
        end
      end

      def failure_context?(context)
        context.respond_to?(:failure?) && context.failure?
      end

      def dispatch_interactor_failure_handlers(handlers:, context:, error:, interactor:, request_object:, params:)
        failure = FailurePayload.new(
          context: context,
          error: error,
          interactor: interactor,
          request_object: request_object,
          params: params,
          controller: self,
        )

        return failure if handlers.empty?

        action_scope = current_interactor_action

        handlers.each do |definition|
          next unless definition.applicable?(action_scope)

          invoke_handler(definition.callable, failure)
        end

        failure
      end

      def invoke_handler(handler, failure)
        result =
          case handler
          when Proc
            handler.arity.zero? ? instance_exec(&handler) : instance_exec(failure, &handler)
          when Symbol, String
            callable_method = method(handler)
            callable_method.arity.zero? ? callable_method.call : callable_method.call(failure)
          else
            if handler.respond_to?(:call)
              call_arity = handler.respond_to?(:arity) ? handler.arity : nil
              call_arity&.zero? ? handler.call : handler.call(failure)
            else
              raise ArgumentError, "Interactor failure handler #{handler.inspect} is not callable"
            end
          end

        failure.handled! if result && !failure.handled?

        failure.handled?
      end

      def emit_failure_signal_if_needed(failure, halt_on_handle)
        return unless failure.handled?

        @_interactor_failure_handled = true

        return unless halt_on_handle

        if respond_to?(:rescue_with_handler)
          raise FailureHandledSignal.new(failure)
        end
      end

      def resolve_error_handlers(custom)
        case custom
        when false
          []
        when nil
          class_handler_definitions + configuration_handler_definitions
        else
          Array(custom).flat_map do |item|
            if item == :defaults || item == :default
              class_handler_definitions + configuration_handler_definitions
            else
              ErrorHandlerDefinition.new(callable: item, only: [], except: [])
            end
          end
        end
      end

      def class_handler_definitions
        Array(self.class.interactor_failure_handler_definitions).dup
      end

      def configuration_handler_definitions
        Array(InteractorSupport.configuration.default_interactor_error_handler).compact.map do |handler|
          ErrorHandlerDefinition.new(callable: handler, only: [], except: [])
        end
      end

      def current_interactor_action
        return action_name.to_sym if respond_to?(:action_name) && action_name

        nil
      end
    end
  end
end
