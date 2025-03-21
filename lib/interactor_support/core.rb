module InteractorSupport
  module Core
    class << self
      def included(base)
        # Only include Interactor if it isn’t already present.
        base.include(Interactor) unless base.included_modules.include?(Interactor)
      end
    end
  end
end
