module InteractorSupport
  module Concerns
    ##
    # Adds transactional support to your interactor using ActiveRecord.
    #
    # The `transaction` method wraps the interactor execution in an `around` block
    # that uses `ActiveRecord::Base.transaction`. If the context fails (via `context.fail!`),
    # the transaction is rolled back automatically using `ActiveRecord::Rollback`.
    #
    # This is useful for ensuring your interactor behaves atomically.
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
          # If the context fails (`context.failure?`), a rollback is triggered automatically.
          # You can customize the transaction behavior using standard ActiveRecord options.
          #
          # @param isolation [Symbol, nil] the transaction isolation level (e.g., `:read_committed`, `:serializable`)
          # @param joinable [Boolean] whether this transaction can join an existing one
          # @param requires_new [Boolean] whether to force a new transaction, even if one already exists
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
