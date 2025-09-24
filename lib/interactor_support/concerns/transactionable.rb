module InteractorSupport
  module Concerns
    ##
    # Adds a declarative `transaction` wrapper around interactor execution using ActiveRecord.
    #
    # Enabling the wrapper ensures that:
    # - The interactor runs inside `ActiveRecord::Base.transaction` with configurable options.
    # - `context.fail!` triggers an `ActiveRecord::Rollback` so partial work is undone.
    #
    # @example Basic usage
    #   class CreateUser
    #     include Interactor
    #     include InteractorSupport::Transactionable
    #
    #     transaction
    #
    #     def call
    #       User.create!(context.user_params)
    #       context.fail!(message: "Simulated failure") if something_wrong?
    #     end
    #   end
    #
    # @see InteractorSupport::Actions
    module Transactionable
      extend ActiveSupport::Concern
      include InteractorSupport::Core

      included do
        class << self
          # Wraps the interactor in a database transaction.
          #
          # If the context fails (`context.failure?`), a rollback is triggered automatically. Supports
          # the same keyword options as `ActiveRecord::Base.transaction`.
          #
          # @param isolation [Symbol, nil] optional transaction isolation level (e.g., `:read_committed`)
          # @param joinable [Boolean] whether this transaction can join an existing one
          # @param requires_new [Boolean] whether to force a new transaction even if one already exists
          #
          # @example Wrap in a basic transaction
          #   transaction
          #
          # @example With custom options
          #   transaction requires_new: true, isolation: :serializable
          def transaction(isolation: nil, joinable: true, requires_new: false)
            around do |interactor|
              ActiveRecord::Base.transaction(isolation: isolation, joinable: joinable, requires_new: requires_new) do
                interactor.call
                raise ActiveRecord::Rollback if context.failure?
              end
            end
          end
        end
      end
    end
  end
end
