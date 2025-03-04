RSpec.describe(InteractorSupport::Concerns::Skippable) do
  describe '.skip' do
    let(:default_interactor) do
      Class.new do
        include Interactor
        include InteractorSupport::Concerns::Skippable

        def call
          context.executed = true
        end
      end
    end

    context ':if true' do
      it 'skips execution when a boolean value is passed' do
        interactor = Class.new(default_interactor) do
          skip if: true
        end
        result = interactor.call
        expect(result.executed).to(be_nil)
      end

      it 'skips execution when a block is passed' do
        interactor = Class.new(default_interactor) do
          skip if: -> { true }
        end
        result = interactor.call
        expect(result.executed).to(be_nil)
      end

      it 'skips execution when a method is passed' do
        interactor = Class.new(default_interactor) do
          skip if: :some_method

          def some_method
            context.condition_met = true
          end
        end
        result = interactor.call
        expect(result.executed).to(be_nil)
        expect(result[:condition_met]).to(be(true))
      end

      it 'skips execution when a context variable is passed' do
        interactor = Class.new(default_interactor) do
          skip if: :condition
        end
        result = interactor.call(condition: true)
        expect(result.executed).to(be_nil)
      end
    end

    context ':if false' do
      it 'executes normally when a boolean value is passed' do
        interactor = Class.new(default_interactor) do
          skip if: false
        end
        result = interactor.call
        expect(result.executed).to(be(true))
      end

      it 'executes normally when a block is passed' do
        interactor = Class.new(default_interactor) do
          skip if: -> { false }
        end
        result = interactor.call
        expect(result.executed).to(be(true))
      end

      it 'executes normally when a method is passed' do
        interactor = Class.new(default_interactor) do
          skip if: :some_method

          def some_method
            context.condition_met = true
            false
          end
        end
        result = interactor.call
        expect(result.executed).to(be(true))
        expect(result.condition_met).to(be(true))
      end

      it 'executes normally when a context variable is passed' do
        interactor = Class.new(default_interactor) do
          skip if: :condition
        end
        result = interactor.call(condition: false)
        expect(result.executed).to(be(true))
      end
    end

    context ':unless true' do
      it 'skips execution when a boolean value is passed' do
        interactor = Class.new(default_interactor) do
          skip unless: true
        end
        result = interactor.call
        expect(result.executed).to(be(true))
      end

      it 'skips execution when a block is passed' do
        interactor = Class.new(default_interactor) do
          skip unless: -> { true }
        end
        result = interactor.call
        expect(result.executed).to(be(true))
      end

      it 'skips execution when a method is passed' do
        interactor = Class.new(default_interactor) do
          skip unless: :some_method

          def some_method
            context.condition_met = true
          end
        end
        result = interactor.call
        expect(result.executed).to(be(true))
        expect(result[:condition_met]).to(be(true))
      end

      it 'skips execution when a context variable is passed' do
        interactor = Class.new(default_interactor) do
          skip unless: :condition
        end
        result = interactor.call(condition: true)
        expect(result.executed).to(be(true))
      end
    end

    context ':unless false' do
      it 'executes normally when a boolean value is passed' do
        interactor = Class.new(default_interactor) do
          skip unless: false
        end
        result = interactor.call
        expect(result.executed).to(be_nil)
      end

      it 'executes normally when a block is passed' do
        interactor = Class.new(default_interactor) do
          skip unless: -> { false }
        end
        result = interactor.call
        expect(result.executed).to(be_nil)
      end

      it 'executes normally when a method is passed' do
        interactor = Class.new(default_interactor) do
          skip unless: :some_method

          def some_method
            context.condition_met = true
            false
          end
        end
        result = interactor.call
        expect(result.executed).to(be_nil)
        expect(result.condition_met).to(be(true))
      end

      it 'executes normally when a context variable is passed' do
        interactor = Class.new(default_interactor) do
          skip unless: :condition
        end
        result = interactor.call(condition: false)
        expect(result.executed).to(be_nil)
      end
    end

    context 'when an interactor already has an around block' do
      it 'does not skip the around block' do
        interactor = Class.new(default_interactor) do
          around do |interactor|
            context.around_executed = true
            interactor.call
          end

          skip if: true
        end

        result = interactor.call
        expect(result.around_executed).to(be(true))
        expect(result.executed).to(be_nil)
      end
    end
  end
end
