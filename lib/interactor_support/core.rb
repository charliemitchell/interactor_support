module InteractorSupport
  ##
  # Core behavior that ensures the `Interactor` module is included
  # when any InteractorSupport concern is mixed in.
  #
  # This module is automatically included by all `InteractorSupport::Concerns`,
  # so you generally do not need to include it manually.
  #
  # @example Included implicitly
  #   class MyInteractor
  #     include InteractorSupport::Concerns::Findable
  #     # => Interactor is automatically included
  #   end
  module Core
    class << self
      ##
      # Ensures the `Interactor` module is included in the base class.
      #
      # This hook runs when `Core` is included by a concern and conditionally
      # includes `Interactor` if not already present.
      #
      # @param base [Class] the class or module including this concern
      def included(base)
        base.include(Interactor) unless base.included_modules.include?(Interactor)
      end
    end
  end
end
