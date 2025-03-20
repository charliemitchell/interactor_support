# frozen_string_literal: true

RSpec.describe(InteractorSupport::Actions) do
  let(:default_interactor) do
    Class.new do
      include Interactor
      include InteractorSupport::Validations

      def call
        context.executed = true
      end
    end
  end

  context 'validates_before' do
    context 'type' do
      context 'when the key is not of the specified type' do
        it 'fails and adds an error to the context' do
          interactor = Class.new(default_interactor) do
            validates_before :foo, type: Integer
          end

          result = interactor.call(foo: 'bar')
          expect(result).to(be_a_failure)
          expect(result.errors).to(include('foo was not of type Integer'))
          expect(result.executed).to(be_nil)
        end
      end
      context 'when the key is of the specified type' do
        it 'succeeds' do
          interactor = Class.new(default_interactor) do
            validates_before :foo, type: Integer
          end

          result = interactor.call(foo: 1)
          expect(result).to(be_a_success)
          expect(result.executed).to(be_truthy)
        end
      end
    end

    context 'presence' do
      context 'when the key is not present' do
        it 'fails and adds an error to the context' do
          interactor = Class.new(default_interactor) do
            validates_before :foo, presence: true
          end

          result = interactor.call
          expect(result).to(be_a_failure)
          expect(result.errors).to(include('foo does not exist'))
          expect(result.executed).to(be_nil)
        end
      end
      context 'when the key is present' do
        it 'succeeds' do
          interactor = Class.new(default_interactor) do
            validates_before :foo, presence: true
          end

          result = interactor.call(foo: 'bar')
          expect(result).to(be_a_success)
        end
      end
    end

    context 'inclusion' do
      context 'when the key is not in the specified list' do
        it 'fails and adds an error to the context' do
          interactor = Class.new(default_interactor) do
            validates_before :foo, inclusion: { in: ['bar', 'baz'] }
          end

          result = interactor.call(foo: 'qux')
          expect(result).to(be_a_failure)
          expect(result.errors).to(include('foo was not in the specified inclusion'))
          expect(result.executed).to(be_nil)
        end
      end
      context 'when the key is in the specified list' do
        it 'succeeds' do
          interactor = Class.new(default_interactor) do
            validates_before :foo, inclusion: { in: ['bar', 'baz'] }
          end

          result = interactor.call(foo: 'bar')
          expect(result).to(be_a_success)
          expect(result.executed).to(be_truthy)
        end
      end
      context 'when the key is in the specified range' do
        it 'succeeds' do
          interactor = Class.new(default_interactor) do
            validates_before :foo, inclusion: { in: 1..10 }
          end

          result = interactor.call(foo: 5)
          expect(result).to(be_a_success)
          expect(result.executed).to(be_truthy)
        end
      end
      context 'when the key is not in the specified range' do
        it 'fails and adds an error to the context' do
          interactor = Class.new(default_interactor) do
            validates_before :foo, inclusion: { in: 1..10 }
          end

          result = interactor.call(foo: 11)
          expect(result).to(be_a_failure)
          expect(result.errors).to(include('foo was not in the specified inclusion'))
          expect(result.executed).to(be_nil)
        end
      end
      context 'when the inclusion params are not a range or array' do
        it 'fails and adds an error to the context' do
          interactor = Class.new(default_interactor) do
            validates_before :foo, inclusion: { in: 'foo' }
          end

          result = interactor.call(foo: 'bar')
          expect(result).to(be_a_failure)
          expect(result.errors).to(include('inclusion validation requires an :in key with an array or range'))
          expect(result.executed).to(be_nil)
        end
      end
      context 'when passing a raw value' do
        it 'fails and adds an error to the context' do
          interactor = Class.new(default_interactor) do
            validates_before :foo, inclusion: ['bar', 'baz']
          end

          result = interactor.call(foo: 'bar')
          expect(result).to(be_a_failure)
          expect(result.errors).to(include('inclusion validation requires an :in key with an array or range'))
          expect(result.executed).to(be_nil)
        end
      end
      context 'when the inclusion hash is missing the :in key' do
        it 'fails and adds an error to the context' do
          interactor = Class.new(default_interactor) do
            validates_before :foo, inclusion: {}
          end

          result = interactor.call(foo: 'bar')
          expect(result).to(be_a_failure)
          expect(result.errors).to(include('inclusion validation requires an :in key with an array or range'))
          expect(result.executed).to(be_nil)
        end
      end
    end

    context 'persisted' do
      it 'fails and adds an error to the context' do
        interactor = Class.new(default_interactor) do
          validates_before :foo, persisted: true
        end

        result = interactor.call
        expect(result).to(be_a_failure)
        expect(result.errors).to(include('persisted validation is only available for after validations'))
        expect(result.executed).to(be_nil)
      end
    end
  end

  context 'validates_after' do
    context 'type' do
      context 'when the key is not of the specified type' do
        it 'fails and adds an error to the context' do
          interactor = Class.new(default_interactor) do
            validates_after :executed, type: String
          end

          result = interactor.call
          expect(result).to(be_a_failure)
          expect(result.errors).to(include('executed was not of type String'))
        end
      end
      context 'when the key is of the specified type' do
        it 'succeeds' do
          interactor = Class.new(default_interactor) do
            validates_after :foo, type: Integer
          end

          result = interactor.call(foo: 1)
          expect(result).to(be_a_success)
          expect(result.executed).to(be_truthy)
        end
      end
    end

    context 'presence' do
      context 'when the key is not present' do
        it 'fails and adds an error to the context' do
          interactor = Class.new(default_interactor) do
            validates_after :foo, presence: true
          end

          result = interactor.call
          expect(result).to(be_a_failure)
          expect(result.errors).to(include('foo does not exist'))
        end
      end
      context 'when the key is present' do
        it 'succeeds' do
          interactor = Class.new(default_interactor) do
            validates_after :foo, presence: true
          end

          result = interactor.call(foo: 'bar')
          expect(result).to(be_a_success)
        end
      end
    end

    context 'inclusion' do
      context 'when the key is not in the specified list' do
        it 'fails and adds an error to the context' do
          interactor = Class.new(default_interactor) do
            validates_after :foo, inclusion: { in: ['bar', 'baz'] }
          end

          result = interactor.call(foo: 'qux')
          expect(result).to(be_a_failure)
          expect(result.errors).to(include('foo was not in the specified inclusion'))
        end
      end
      context 'when the key is in the specified list' do
        it 'succeeds' do
          interactor = Class.new(default_interactor) do
            validates_after :foo, inclusion: { in: ['bar', 'baz'] }
          end

          result = interactor.call(foo: 'bar')
          expect(result).to(be_a_success)
        end
      end
      context 'when the key is in the specified range' do
        it 'succeeds' do
          interactor = Class.new(default_interactor) do
            validates_after :foo, inclusion: { in: 1..10 }
          end

          result = interactor.call(foo: 5)
          expect(result).to(be_a_success)
        end
      end
      context 'when the key is not in the specified range' do
        it 'fails and adds an error to the context' do
          interactor = Class.new(default_interactor) do
            validates_after :foo, inclusion: { in: 1..10 }
          end

          result = interactor.call(foo: 11)
          expect(result).to(be_a_failure)
          expect(result.errors).to(include('foo was not in the specified inclusion'))
        end
      end
      context 'when the inclusion params are not a range or array' do
        it 'fails and adds an error to the context' do
          interactor = Class.new(default_interactor) do
            validates_after :foo, inclusion: { in: 'foo' }
          end

          result = interactor.call(foo: 'bar')
          expect(result).to(be_a_failure)
          expect(result.errors).to(include('inclusion validation requires an :in key with an array or range'))
        end
      end
      context 'when passing a raw value' do
        it 'fails and adds an error to the context' do
          interactor = Class.new(default_interactor) do
            validates_after :foo, inclusion: ['bar', 'baz']
          end

          result = interactor.call(foo: 'bar')
          expect(result).to(be_a_failure)
          expect(result.errors).to(include('inclusion validation requires an :in key with an array or range'))
        end
      end
      context 'when the inclusion hash is missing the :in key' do
        it 'fails and adds an error to the context' do
          interactor = Class.new(default_interactor) do
            validates_after :foo, inclusion: {}
          end

          result = interactor.call(foo: 'bar')
          expect(result).to(be_a_failure)
          expect(result.errors).to(include('inclusion validation requires an :in key with an array or range'))
        end
      end
    end

    context 'persisted' do
      let(:genre_class) do
        Class.new(ApplicationRecord) do
          self.table_name = 'genres'
        end
      end

      let(:persisted_genre) { genre_class.create(name: 'foo') }
      let(:unpersisted_genre) { genre_class.new(name: 'bar') }

      context 'when the key is not persisted' do
        it 'fails and adds an error to the context' do
          interactor = Class.new(default_interactor) do
            validates_after :unpersisted_genre, persisted: true
          end

          result = interactor.call(unpersisted_genre: unpersisted_genre)
          expect(result).to(be_a_failure)
          expect(result.errors).to(include('unpersisted_genre was not persisted'))
        end
      end
      context 'when the key is persisted' do
        it 'succeeds' do
          interactor = Class.new(default_interactor) do
            validates_after :persisted_genre, persisted: true
          end

          result = interactor.call(persisted_genre: persisted_genre)
          expect(result).to(be_a_success)
          expect(result.executed).to(be_truthy)
        end
      end
      context 'when the key is not an ApplicationRecord' do
        it 'fails and adds an error to the context' do
          interactor = Class.new(default_interactor) do
            validates_after :foo, persisted: true
          end

          result = interactor.call(foo: 'bar')
          expect(result).to(be_a_failure)
          expect(result.errors).to(
            include('foo is not an ApplicationRecord, which is required for persisted validation'),
          )
        end
      end
    end
  end

  context 'required' do
    context 'when the key is not present' do
      it 'fails and adds an error to the context' do
        class DummyInteractor
          include Interactor
          include InteractorSupport::Validations

          required :foo

          def call
            context.executed = true
          end
        end
        result = DummyInteractor.call
        expect(result).to(be_a_failure)
        expect(result.errors).to(include('Foo can\'t be blank'))
        expect(result.executed).to(be_nil)
      end
    end
    context 'when multiple keys are missing' do
      it 'fails and adds an error to the context for each missing key' do
        class DummyInteractor
          include Interactor
          include InteractorSupport::Validations

          required :foo, :bar

          def call
            context.executed = true
          end
        end

        result = DummyInteractor.call
        expect(result).to(be_a_failure)
        expect(result.errors).to(include('Foo can\'t be blank'))
        expect(result.errors).to(include('Bar can\'t be blank'))
        expect(result.executed).to(be_nil)
      end
    end
    context 'when the key is present' do
      it 'succeeds' do
        interactor = Class.new(default_interactor) do
          required :foo
        end

        result = interactor.call(foo: 'bar')
        expect(result).to(be_a_success)
        expect(result.executed).to(be_truthy)
      end

      it 'sets the attr_accessor' do
        interactor = Class.new(default_interactor) do
          required :foo

          def call
            raise 'foo is not set' unless foo
          end
        end

        result = interactor.call(foo: 'bar')
        expect(result).to(be_a_success)
      end
    end
    context 'when required attributes have ActiveModel validations' do
      it 'fails when the validation does not pass' do
        class DummyInteractor
          include Interactor
          include InteractorSupport::Validations

          required email: { presence: true, format: { with: URI::MailTo::EMAIL_REGEXP } }

          def call
            context.executed = true
          end
        end

        result = DummyInteractor.call(email: 'invalid-email')
        expect(result).to(be_a_failure)
        expect(result.errors).to(include('Email is invalid'))
      end

      it 'succeeds when the validation passes' do
        interactor = Class.new(default_interactor) do
          required email: { presence: true, format: { with: URI::MailTo::EMAIL_REGEXP } }
        end

        result = interactor.call(email: 'user@example.com')
        expect(result).to(be_a_success)
      end
    end
    context 'when required attributes have multiple validations' do
      it 'fails when any validation does not pass' do
        class DummyInteractor
          include Interactor
          include InteractorSupport::Validations

          required password: { presence: true, length: { minimum: 6 } }

          def call
            context.executed = true
          end
        end

        result = DummyInteractor.call(password: '123')
        expect(result).to(be_a_failure)
        expect(result.errors).to(include('Password is too short (minimum is 6 characters)'))
      end

      it 'succeeds when all validations pass' do
        interactor = Class.new(default_interactor) do
          required password: { presence: true, length: { minimum: 6 } }
        end

        result = interactor.call(password: 'securepassword')
        expect(result).to(be_a_success)
      end
    end
    context 'when a required key with validations is missing' do
      it 'fails and reports it as required' do
        class UsernameRequiredInteractor
          include Interactor
          include InteractorSupport::Validations

          required username: { presence: true }
        end

        result = UsernameRequiredInteractor.call
        expect(result).to(be_a_failure)
        expect(result.errors).to(include("Username can't be blank"))
      end
    end
  end

  context 'optional' do
    context 'when the key is not present' do
      it 'succeeds' do
        interactor = Class.new(default_interactor) do
          optional :foo
        end

        result = interactor.call
        expect(result).to(be_a_success)
        expect(result.executed).to(be_truthy)
      end
    end
    context 'when the key is present' do
      it 'succeeds' do
        interactor = Class.new(default_interactor) do
          optional :foo
        end

        result = interactor.call(foo: 'bar')
        expect(result).to(be_a_success)
        expect(result.executed).to(be_truthy)
      end
      it 'sets the attr_accessor' do
        interactor = Class.new(default_interactor) do
          optional :foo

          def call
            raise 'foo is not set' unless foo
          end
        end

        result = interactor.call(foo: 'bar')
        expect(result).to(be_a_success)
      end
    end
    context 'when optional attributes have ActiveModel validations' do
      it 'fails when the validation does not pass' do
        class OptionalAgeInteractor
          include Interactor
          include InteractorSupport::Validations

          optional age: { numericality: { greater_than: 18 } }
        end

        result = OptionalAgeInteractor.call(age: 15)
        expect(result).to(be_a_failure)
        expect(result.errors).to(include('Age must be greater than 18'))
      end

      it 'succeeds when the validation passes' do
        interactor = Class.new(default_interactor) do
          optional age: { numericality: { greater_than: 18 } }
        end

        result = interactor.call(age: 25)
        expect(result).to(be_a_success)
      end
    end
    context 'when an optional key with validations is missing' do
      it 'succeeds without checking validations' do
        class OptionalAgeInteractorSuccess
          include Interactor
          include InteractorSupport::Validations

          optional age: { numericality: { greater_than: 18 } }
        end

        result = OptionalAgeInteractorSuccess.call # No age provided
        expect(result).to(be_a_success)
      end
    end
  end
end
