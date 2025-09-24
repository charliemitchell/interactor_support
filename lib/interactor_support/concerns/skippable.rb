# frozen_string_literal: true

module InteractorSupport
  module Concerns
    ##
    # Adds a declarative `skip` helper for short-circuiting interactor execution.
    #
    # Conditions run inside an `around` callback, accepting symbols, booleans, or lambdas executed via
    # `instance_exec`. Use this to prevent unnecessary work when preconditions fail.
    #
    # - Symbols first look for an interactor instance method, then fall back to context values.
    # - Lambdas have full access to the interactor instance and context.
    #
    # @example Skip if the user is already authenticated (symbol in context)
    #   skip if: :user_authenticated
    #
    # @example Skip unless a method returns true
    #   skip unless: :should_run?
    #
    # @example Skip based on a lambda
    #   skip if: -> { mode == "test" }
    #
    # @see InteractorSupport::Actions
    module Skippable
      extend ActiveSupport::Concern
      include InteractorSupport::Core

      included do
        class << self
          ##
          # Skips the interactor based on a condition provided via `:if` or `:unless`.
          #
          # A truthy `:if` or falsy `:unless` prevents `call` from running; otherwise execution continues.
          #
          # @param options [Hash]
          # @option options [Proc, Symbol, Boolean] :if a condition that must be truthy to skip
          # @option options [Proc, Symbol, Boolean] :unless a condition that must be falsy to skip
          #
          # @example Skip if a context value is truthy
          #   skip if: :user_authenticated
          #
          # @example Skip unless a method returns true
          #   skip unless: :should_run?
          #
          # @example Skip based on a lambda
          #   skip if: -> { context[:mode] == "test" }
          def skip(**options)
            around do |interactor|
              unless options[:if].nil?
                condition = if options[:if].is_a?(Proc)
                  context.instance_exec(&options[:if])
                elsif options[:if].is_a?(Symbol) && respond_to?(options[:if])
                  send(options[:if])
                elsif options[:if].is_a?(Symbol)
                  context[options[:if]]
                else
                  options[:if]
                end

                next if condition
              end

              unless options[:unless].nil?
                condition = if options[:unless].is_a?(Proc)
                  context.instance_exec(&options[:unless])
                elsif options[:unless].is_a?(Symbol) && respond_to?(options[:unless])
                  send(options[:unless])
                elsif options[:unless].is_a?(Symbol)
                  context[options[:unless]]
                else
                  options[:unless]
                end

                next unless condition
              end

              interactor.call
            end
          end
        end
      end
    end
  end
end
