# frozen_string_literal: true

RSpec.describe InteractorSupport::Actions do
  describe '.included' do
    it 'includes InteractorSupport::Concerns::Skippable' do
      interactor = Class.new do
        include Interactor
        include InteractorSupport::Actions
      end

      expect(interactor.ancestors).to(include(InteractorSupport::Concerns::Skippable))
    end

    it 'includes InteractorSupport::Concerns::Transactionable' do
      interactor = Class.new do
        include Interactor
        include InteractorSupport::Actions
      end

      expect(interactor.ancestors).to(include(InteractorSupport::Concerns::Transactionable))
    end

    it 'includes InteractorSupport::Concerns::Updatable' do
      interactor = Class.new do
        include Interactor
        include InteractorSupport::Actions
      end

      expect(interactor.ancestors).to(include(InteractorSupport::Concerns::Updatable))
    end

    it 'includes InteractorSupport::Concerns::Findable' do
      interactor = Class.new do
        include Interactor
        include InteractorSupport::Actions
      end

      expect(interactor.ancestors).to(include(InteractorSupport::Concerns::Findable))
    end

    it 'includes InteractorSupport::Concerns::Transformable' do
      interactor = Class.new do
        include Interactor
        include InteractorSupport::Actions
      end

      expect(interactor.ancestors).to(include(InteractorSupport::Concerns::Transformable))
    end
  end
end
