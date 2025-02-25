# frozen_string_literal: true

module InteractorSupport
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
