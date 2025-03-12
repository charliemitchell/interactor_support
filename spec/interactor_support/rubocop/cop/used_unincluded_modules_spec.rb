require 'rubocop'
require 'rubocop/rspec/support'
require './lib/interactor_support/rubocop/cop/used_unincluded_modules.rb'

RSpec.describe(RuboCop::Cop::UsedUnincludedModules, :config) do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new(config) }
  let(:config) { RuboCop::Config.new }

  context 'when an InteractorSupport module is included but Interactor is missing' do
    it 'registers an offense for missing Interactor' do
      expect_offense(<<~RUBY)
        class SomeInteractor
          include InteractorSupport::Concerns::Findable
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Cop/UsedUnincludedModules: `include Interactor` is required when including `InteractorSupport::Concerns::Findable`.
        end
      RUBY
    end
  end

  context 'when Interactor is included but a required InteractorSupport module is missing' do
    it 'registers an info-level message for missing modules' do
      expect_offense(<<~RUBY, severity: :info)
        class SomeInteractor
          include Interactor
          find_by(:post)
          ^^^^^^^^^^^^^^ Cop/UsedUnincludedModules: Method `find_by` is used but `InteractorSupport::Concerns::Findable` is not included.
        end
      RUBY
    end
  end

  context 'when multiple methods are used but corresponding modules are missing' do
    it 'lists all missing modules in info-level offenses' do
      expect_offense(<<~RUBY)
        class SomeInteractor
          include Interactor

          def perform
            find_by(:post)
            ^^^^^^^^^^^^^^ Cop/UsedUnincludedModules: Method `find_by` is used but `InteractorSupport::Concerns::Findable` is not included.
            validates :name, presence: true
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Cop/UsedUnincludedModules: Method `validates` is used but `InteractorSupport::Validations` is not included.
          end
        end
      RUBY
    end
  end

  context 'when Interactor and all required modules are included' do
    let(:source) do
      <<~RUBY
        class SomeInteractor
          include Interactor
          include InteractorSupport::Concerns::Findable

          def perform
            find_by(:post)
          end
        end
      RUBY
    end

    it 'does not register any offense' do
      expect_no_offenses(source)
    end
  end

  context 'when Interactor and multiple required modules are included' do
    let(:source) do
      <<~RUBY
        class SomeInteractor
          include Interactor
          include InteractorSupport::Concerns::Findable
          include InteractorSupport::Validations

          def perform
            find_by(:post)
            validates :name, presence: true
          end
        end
      RUBY
    end

    it 'does not register any offense' do
      expect_no_offenses(source)
    end
  end
end
