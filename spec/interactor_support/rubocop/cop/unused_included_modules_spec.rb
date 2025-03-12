# rubocop:disable Layout/LineLength
require 'rubocop'
require 'rubocop/rspec/support'
require './lib/interactor_support/rubocop/cop/unused_included_modules.rb'

RSpec.describe(RuboCop::Cop::UnusedIncludedModules, :config) do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new(config) }
  let(:config) { RuboCop::Config.new }

  context 'when a module is included but not used' do
    it 'registers an offense for Skippable and auto-corrects it' do
      source = inspect_source(
        <<~RUBY,
          class SomeInteractor
            include InteractorSupport::Concerns::Findable
            include InteractorSupport::Concerns::Skippable

            find_by(:post)
          end

        RUBY
      )

      expect(source.first.message).to(
        eq('Cop/UnusedIncludedModules: Module `InteractorSupport::Concerns::Skippable` is included but its methods are not used in this class.'),
      )
    end
  end

  context 'when InteractorSupport (group module) is included but some modules are unused' do
    let(:source) do
      <<~RUBY
        class SomeInteractor
          include InteractorSupport

          def perform
            find_by(:post)
          end
        end
      RUBY
    end

    it 'registers an offense listing specific unused modules' do
      inspection = inspect_source(source)
      puts inspection.first.message
      expect(inspection.first.message).to(
        eq('Cop/UnusedIncludedModules: Use `include InteractorSupport::Concerns::Findable` instead.'),
      )
    end

    it 'recognizes ActiveModel::Validations' do
      source = inspect_source(
        <<~RUBY,
          class SomeInteractor
            include InteractorSupport

            validates :name, presence: true
          end
        RUBY
      )

      expect(source.first.message).to(
        eq('Cop/UnusedIncludedModules: Use `include InteractorSupport::Validations` instead.'),
      )
    end

    it 'lists suggest multiple modules' do
      source = inspect_source(
        <<~RUBY,
          class SomeInteractor
            include InteractorSupport

            validates :name, presence: true
            find_by(:post)
          end
        RUBY
      )
      puts source.first.message
      expect(source.first.message).to(
        eq('Cop/UnusedIncludedModules: Use `include InteractorSupport::Validations, include InteractorSupport::Concerns::Findable` instead.'),
      )
    end
  end

  context 'when a module is included and used' do
    let(:source) do
      <<~RUBY
        class SomeInteractor
          include InteractorSupport::Concerns::Findable

          def perform
            find_by(:post)
          end
        end
      RUBY
    end

    it 'does not register an offense' do
      expect_no_offenses(source)
    end
  end
end
# rubocop:enable Layout/LineLength
