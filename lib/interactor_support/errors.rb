module InteractorSupport
  module Errors
    class UnknownAttribute < StandardError
      def initialize(attribute)
        super("Unknown attribute: #{attribute}")
      end
    end
  end
end
