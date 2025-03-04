require 'rubocop'
require 'rubocop/rspec/support'
require './lib/interactor_support/rubocop/cop/require_required_for_interactor_support.rb'

RSpec.describe(RuboCop::Cop::RequireRequiredForInteractorSupport) do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new(config) }
  let(:config) { RuboCop::Config.new }

  context 'when including InteractorSupport without calling required' do
    it 'registers an offense' do
      inspect_source(
        <<~RUBY,
          class LocationRequest
            include InteractorSupport
          end
        RUBY
      )
      expect(cop.offenses.size).to(be(1))
      expect(cop.offenses.first.message).to(
        eq('Cop/RequireRequiredForInteractorSupport: Classes including `InteractorSupport` or `InteractorSupport::Validations` must invoke `required`.'), # rubocop:disable Layout/LineLength
      )
    end
  end

  context 'when including InteractorSupport::Validations without calling required' do
    it 'registers an offense' do
      inspect_source(
        <<~RUBY,
          class LocationRequest
            include InteractorSupport::Validations
          end
        RUBY
      )

      expect(cop.offenses.size).to(be(1))
      expect(cop.offenses.first.message).to(
        eq('Cop/RequireRequiredForInteractorSupport: Classes including `InteractorSupport` or `InteractorSupport::Validations` must invoke `required`.'), # rubocop:disable Layout/LineLength
      )
    end
  end

  context 'when including InteractorSupport::Validations without calling required on a complex class' do
    it 'registers an offense' do
      inspect_source(
        <<~RUBY,
          class LocationRequest
            attribute :email, transform: :strip
            validates :email, presence: true
            included do
              include InteractorSupport::Validations
              required :email
            end
          end
        RUBY
      )

      expect(cop.offenses.size).to(be(1))
      expect(cop.offenses.first.message).to(
        eq('Cop/RequireRequiredForInteractorSupport: Classes including `InteractorSupport` or `InteractorSupport::Validations` must invoke `required`.'), # rubocop:disable Layout/LineLength
      )
    end
  end

  context 'when including InteractorSupport and calling required' do
    let(:source) do
      <<~RUBY
        class LocationRequest
          include InteractorSupport
          required :email
        end
      RUBY
    end

    it 'does not register an offense' do
      inspect_source(source)
      expect(cop.offenses.size).to(be(0))
    end
  end
end
