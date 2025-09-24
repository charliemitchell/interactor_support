# lib/interactor_support/version.rb
module InteractorSupport
  ##
  # Bundles the most common InteractorSupport concerns into a single include.
  #
  # Mix this into an `Interactor` or `Interactor::Organizer` to gain access to:
  #
  # - {InteractorSupport::Concerns::Skippable} — Conditionally skip execution
  # - {InteractorSupport::Concerns::Transactionable} — Wrap logic in an ActiveRecord transaction
  # - {InteractorSupport::Concerns::Updatable} — Update records using context-driven attributes
  # - {InteractorSupport::Concerns::Findable} — Find one or many records into context
  # - {InteractorSupport::Concerns::Transformable} — Normalize or modify context values before execution
  #
  # @example Use in an interactor
  #   class UpdateUser
  #     include Interactor
  #     include InteractorSupport::Actions
  #
  #     find_by :user
  #
  #     transform :email, with: [:strip, :downcase]
  #
  #     update :user, attributes: { email: :email }
  #   end
  #
  #
  # @see InteractorSupport::Concerns::Skippable
  # @see InteractorSupport::Concerns::Transactionable
  # @see InteractorSupport::Concerns::Updatable
  # @see InteractorSupport::Concerns::Findable
  # @see InteractorSupport::Concerns::Transformable
  module Actions
    extend ActiveSupport::Concern

    included do
      include InteractorSupport::Concerns::Skippable
      include InteractorSupport::Concerns::Transactionable
      include InteractorSupport::Concerns::Updatable
      include InteractorSupport::Concerns::Findable
      include InteractorSupport::Concerns::Transformable
    end
  end
end
