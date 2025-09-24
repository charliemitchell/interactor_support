module InteractorSupport
  module Concerns
    ##
    # Adds helpers for preparing context data before the interactor `call` executes.
    #
    # - `context_variable` seeds the context with static values or lazily evaluated lambdas.
    # - `transform` normalizes existing context values using symbols, lambdas, or chains of both.
    #
    # @example Assign context variables before the interactor runs
    #   context_variable user: -> { User.find(user_id) }, numbers: [1, 2, 3]
    #
    # @example Normalize email and name before using them
    #   transform :email, :name, with: [:strip, :downcase]
    #
    # @example Apply a lambda to clean up input
    #   transform :name, with: ->(value) { value.gsub(/\s+/, ' ').strip }
    #
    # @example Mixing symbols and lambdas
    #   transform :email, with: [:strip, :downcase, -> { email.gsub(/\s+/, '') }]
    #
    # @see InteractorSupport::Actions
    module Transformable
      extend ActiveSupport::Concern
      include InteractorSupport::Core

      included do
        class << self
          # Assigns one or more values to the context before the interactor runs.
          #
          # Values can be static or lazily evaluated with a proc using `instance_exec`, which has
          # access to the interactor instance and context.
          #
          # @param key_values [Hash{Symbol => Object, Proc}] mapping of context keys to values or Procs
          #
          # @example Static and dynamic values
          #   context_variable first_post: Post.first
          #   context_variable user: -> { User.find(user_id) }
          #   context_variable numbers: [1, 2, 3]
          def context_variable(key_values)
            before do
              key_values.each do |key, value|
                context[key] = if value.is_a?(Proc)
                  context.instance_exec(&value)
                else
                  value
                end
              end
            end
          end

          # Transforms one or more context values using symbols, procs, or chains of both.
          #
          # - Symbols call the method on the current value (e.g., `:strip`).
          # - Procs run via `instance_exec`, so they can reach other context values.
          # - Arrays allow combining multiple operations in order.
          #
          # Any transformation failure uses `context.fail!` with a helpful error message so the
          # interactor halts gracefully.
          #
          # @param keys [Array<Symbol>] one or more context keys to transform
          # @param with [Symbol, Array<Symbol, Proc>, Proc] method name(s) or a proc used to transform values
          #
          # @raise [ArgumentError] if no keys are given, or if an invalid `with:` value is passed
          #
          # @example Single method
          #   transform :email, with: :strip
          #
          # @example Method chain
          #   transform :email, with: [:strip, :downcase]
          #
          # @example Lambda
          #   transform :url, with: ->(value) { value.downcase.strip }
          #
          # @example Multiple keys
          #   transform :email, :name, with: [:downcase, :strip]
          #
          # @example Normalize user input
          #   transform :email, :name, with: [
          #     :strip,
          #     :downcase,
          #     ->(value) { value.gsub(/\s+/, ' ') }, # collapse duplicate spaces
          #   ]
          #
          #   # Result:
          #   # context[:email] = "someone@example.com"
          #   # context[:name]  = "john doe"
          def transform(*keys, with: [])
            before do
              if keys.empty?
                raise ArgumentError, 'transform action requires at least one key.'
              end

              keys.each do |key|
                if with.is_a?(Proc)
                  begin
                    context[key] = context.instance_exec(&with)
                  rescue => e
                    context.fail!(errors: ["#{key} failed to transform: #{e.message}"])
                  end
                elsif with.is_a?(Array)
                  with.each do |method|
                    if method.is_a?(Proc)
                      begin
                        context[key] = context.instance_exec(&method)
                      rescue => e
                        context.fail!(errors: ["#{key} failed to transform: #{e.message}"])
                      end
                    else
                      context.fail!(
                        errors: ["#{key} does not respond to all transforms"],
                      ) unless context[key].respond_to?(method)

                      context[key] = context[key].send(method)
                    end
                  end
                elsif with.is_a?(Symbol) && context[key].respond_to?(with)
                  context[key] = context[key].send(with)
                elsif with.is_a?(Symbol)
                  context.fail!(errors: ["#{key} does not respond to #{with}"])
                else
                  raise ArgumentError, 'transform requires `with` to be a symbol or array of symbols.'
                end
              end
            end
          end
        end
      end
    end
  end
end
