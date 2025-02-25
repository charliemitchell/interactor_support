module InteractorSupport
  module Concerns
    module Transactionable
      extend ActiveSupport::Concern

      included do
        class << self
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