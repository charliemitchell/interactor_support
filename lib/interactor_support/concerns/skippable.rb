# frozen_string_literal: true

module InteractorSupport
  module Concerns
    ##
    # Adds a DSL method to conditionally skip an interactor.
    #
    # This concern provides a `skip` method that wraps the interactor in an `around` block.
    # You can pass an `:if` or `:unless` condition using a Proc, Symbol, or literal.
    # The condition will be evaluated at runtime to determine whether to run the interactor.
    #
    # - Symbols will be looked up on the interactor or in the context.
    # - Lambdas/Procs are evaluated using `instance_exec` with full access to context.
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
          # This wraps the interactor in an `around` hook, and conditionally skips
          # execution based on truthy/falsy evaluation of the provided options.
          #
          # The condition can be a Proc (evaluated in context), a Symbol (used to call a method or context key), or a literal value.
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
