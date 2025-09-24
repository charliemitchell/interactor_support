# frozen_string_literal: true

class DummyRequestObject
  include InteractorSupport::RequestObject

  attribute :order, :metadata, :flags, :internal, :custom
  attribute :id, :secret, :source, :location
  attribute :ip, :foo, :debug
end

class InvalidDummyRequestObject
  include InteractorSupport::RequestObject

  attribute :name

  validates :name, presence: true
end

class DummyInteractor
  include Interactor

  def call
    context.message = 'Hello, world!'
  end
end

class DummyOrganizer
  include Interactor::Organizer
  organize DummyInteractor
end

class SimpleRequestObject
  include InteractorSupport::RequestObject

  attribute :value
end

class FailingInteractor
  include Interactor

  def call
    context.fail!(errors: ['boom'])
  end
end

class ExplodingInteractor
  include Interactor

  def call
    raise StandardError, 'kaboom'
  end
end

RSpec.describe(InteractorSupport::Concerns::Organizable) do
  let(:test_class) do
    Class.new do
      include InteractorSupport::Concerns::Organizable

      attr_accessor :params, :action_name

      def initialize(params)
        @params = params
        @action_name = :create
      end
    end
  end

  let(:raw_params) do
    {
      order: { id: 1, secret: 'no' },
      metadata: { source: 'web', location: { ip: '1.2.3.4' } },
      flags: { foo: true },
      internal: 'x',
      external: { id: 3, sources: ['a', 'b'] },
    }
  end

  let(:permitted_params) { raw_params.deep_dup }

  let(:instance) do
    test_class.new(double(:params, permit!: permitted_params))
  end

  describe '#request_params' do
    it 'returns all params when no top-level keys are passed' do
      result = instance.request_params
      expect(result).to(eq(raw_params))
    end

    it 'returns only top-level keys' do
      result = instance.request_params(:order, :flags)
      expect(result).to(eq(order: { id: 1, secret: 'no' }, flags: { foo: true }))
    end

    it 'merges extra values' do
      result = instance.request_params(:order, merge: { injected: true })
      expect(result).to(include(:order, injected: true))
    end

    it 'removes nested keys with `except:`' do
      result = instance.request_params(:order, except: [[:order, :secret]])
      expect(result).to(eq(order: { id: 1 }))
    end

    it 'flattens a hash with `rewrite:`' do
      result = instance.request_params(:order, rewrite: [{ order: { flatten: true } }])
      expect(result).to(eq(id: 1, secret: 'no'))
    end

    it 'renames and filters keys' do
      result = instance.request_params(:metadata, rewrite: [{ metadata: { as: :meta, only: [:source] } }])
      expect(result).to(eq(meta: { source: 'web' }))
    end

    it 'applies default when key is missing' do
      result = instance.request_params(:missing, rewrite: [{ missing: { default: { id: nil } } }])
      expect(result).to(eq(missing: { id: nil }))
    end

    it 'merges nested keys inside rewritten section' do
      result = instance.request_params(:flags, rewrite: [{ flags: { merge: { debug: true } } }])
      expect(result).to(eq(flags: { foo: true, debug: true }))
    end

    it 'flattens specific nested keys' do
      result = instance.request_params(:metadata, rewrite: [{ metadata: { flatten: [:location] } }])
      expect(result).to(eq(metadata: { source: 'web', ip: '1.2.3.4' }))
    end

    it 'raises an ArgumentError when trying to flatten an array of hashes' do
      expect do
        instance.request_params(:external, rewrite: [{ external: { flatten: [:sources] } }])
      end.to(raise_error(
        ArgumentError,
        'Cannot flatten array for the key `sources`. Flattening arrays of hashes is not supported.',
      ))
    end
  end

  describe '#organize' do
    it 'calls interactor with request object and no context_key' do
      result = instance.organize(
        DummyInteractor,
        params: { order: 'ok' },
        request_object: DummyRequestObject,
      )
      expect(result).to(be_a(Interactor::Context))
      expect(result.message).to(eq('Hello, world!'))
    end

    it 'calls interactor with request object under context_key' do
      result = instance.organize(
        DummyOrganizer,
        params: { flags: 'yes' },
        request_object: DummyRequestObject,
        context_key: :custom,
      )
      expect(result).to(be_a(Interactor::Context))
      expect(result.message).to(eq('Hello, world!'))
      expect(result.custom[:flags]).to(eq('yes'))
    end

    it 'raises a wrapped error when the request object is invalid' do
      expect do
        instance.organize(
          DummyInteractor,
          params: {},
          request_object: InvalidDummyRequestObject,
        )
      end.to(raise_error(InteractorSupport::Errors::InvalidRequestObject) do |error|
        expect(error.request_class).to(eq(InvalidDummyRequestObject))
        expect(error.errors).to(include("Name can't be blank"))
      end)
    end
  end

  describe 'failure handlers' do
    let(:controller_class) do
      Class.new do
        class << self
          def rescue_from(exception_class, &block)
            rescue_handlers[exception_class] = block
          end

          def rescue_handlers
            @rescue_handlers ||= {}
          end
        end

        include InteractorSupport::Concerns::Organizable

        attr_accessor :params, :action_name, :handled_failures, :after_hook_called, :called_handlers

        def initialize(params = {})
          @params = params
          @action_name = :create
          @handled_failures = []
          @after_hook_called = false
          @called_handlers = []
        end

        def rescue_with_handler(exception)
          handler = self.class.rescue_handlers[exception.class]
          return false unless handler

          instance_exec(exception, &handler)
          true
        end

        def run_with(interactor:, request_object:, params: self.params, **options)
          organize(interactor, request_object: request_object, params: params, **options)
          @after_hook_called = true
        end
      end
    end

    let(:controller) { controller_class.new(value: 'anything') }

    after do
      controller_class.reset_interactor_failure_handlers!
      controller_class.rescue_handlers.clear
      InteractorSupport.configure do |config|
        config.default_interactor_error_handler = nil
      end
    end

    def execute_action(controller)
      controller.run_with(interactor: FailingInteractor, request_object: SimpleRequestObject)
    rescue InteractorSupport::Concerns::Organizable::FailureHandledSignal => signal
      controller.rescue_with_handler(signal)
    end

    it 'invokes registered handler and halts execution when handled' do
      controller_class.handle_interactor_failure(:render_failure)

      controller.define_singleton_method(:render_failure) do |failure|
        handled_failures << failure
        called_handlers << :render_failure
        failure.handled!
      end

      expect { execute_action(controller) }.not_to(raise_error)
      expect(controller.after_hook_called).to(be(false))
      expect(controller.handled_failures.length).to(eq(1))
      expect(controller.interactor_failure_handled?).to(be(true))
    end

    it 'allows continuing when halt_on_handle is false' do
      controller_class.handle_interactor_failure(:render_failure)

      controller.define_singleton_method(:render_failure) do |failure|
        handled_failures << failure
        failure.handled!
      end

      controller.run_with(
        interactor: FailingInteractor,
        request_object: SimpleRequestObject,
        halt_on_handle: false,
      )

      expect(controller.after_hook_called).to(be(true))
      expect(controller.interactor_failure_handled?).to(be(true))
    end

    it 'supports per-call handler overrides including defaults' do
      controller_class.handle_interactor_failure(:render_failure)

      controller.define_singleton_method(:render_failure) do |failure|
        called_handlers << :render_failure
        failure.handled!
      end

      controller.define_singleton_method(:audit_failure) do |failure|
        called_handlers << :audit_failure
        failure.handled!
      end

      begin
        controller.run_with(
          interactor: FailingInteractor,
          request_object: SimpleRequestObject,
          error_handler: [:audit_failure, :defaults],
        )
      rescue InteractorSupport::Concerns::Organizable::FailureHandledSignal => signal
        controller.rescue_with_handler(signal)
      end

      expect(controller.called_handlers).to(eq([:audit_failure, :render_failure]))
    end

    it 'respects :only scoping on handlers' do
      controller_class.handle_interactor_failure(:only_handler, only: :update)

      controller.define_singleton_method(:only_handler) do |failure|
        called_handlers << :only_handler
        failure.handled!
      end

      # Default action (:create) should skip the handler
      controller.run_with(interactor: FailingInteractor, request_object: SimpleRequestObject, halt_on_handle: false)
      expect(controller.called_handlers).to(be_empty)
      expect(controller.interactor_failure_handled?).to(be(false))

      controller.action_name = :update
      controller.called_handlers.clear

      begin
        controller.run_with(interactor: FailingInteractor, request_object: SimpleRequestObject)
      rescue InteractorSupport::Concerns::Organizable::FailureHandledSignal => signal
        controller.rescue_with_handler(signal)
      end

      expect(controller.called_handlers).to(eq([:only_handler]))
    end

    it 'handles validation errors before interactor call' do
      controller_class.handle_interactor_failure(:render_failure)

      controller.define_singleton_method(:render_failure) do |failure|
        handled_failures << failure
        failure.handled!
      end

      begin
        controller.run_with(
          interactor: DummyInteractor,
          request_object: InvalidDummyRequestObject,
          params: {},
        )
      rescue InteractorSupport::Concerns::Organizable::FailureHandledSignal => signal
        controller.rescue_with_handler(signal)
      end

      expect(controller.handled_failures.first.error).to(be_a(InteractorSupport::Errors::InvalidRequestObject))
    end

    it 'handles exceptions raised during interactor execution' do
      controller_class.handle_interactor_failure(:render_failure)

      controller.define_singleton_method(:render_failure) do |failure|
        handled_failures << failure
        failure.handled!
      end

      begin
        controller.run_with(interactor: ExplodingInteractor, request_object: SimpleRequestObject)
      rescue InteractorSupport::Concerns::Organizable::FailureHandledSignal => signal
        controller.rescue_with_handler(signal)
      end

      expect(controller.handled_failures.first.error).to(be_a(StandardError))
    end

    it 'uses the globally configured default handler when none are registered' do
      InteractorSupport.configure do |config|
        config.default_interactor_error_handler = :render_failure
      end

      controller.define_singleton_method(:render_failure) do |failure|
        handled_failures << failure
        failure.handled!
      end

      begin
        controller.run_with(interactor: FailingInteractor, request_object: SimpleRequestObject)
      rescue InteractorSupport::Concerns::Organizable::FailureHandledSignal => signal
        controller.rescue_with_handler(signal)
      end

      expect(controller.handled_failures.length).to(eq(1))
    end
  end

  describe 'FailurePayload' do
    let(:error_with_errors) { double('error', errors: double('errors', present?: true), message: 'test error') }
    let(:error_with_message) { double('error', message: 'test message') }
    let(:error_with_status) { double('error', status: 422) }
    let(:context_with_errors) { double('context', errors: double('errors', present?: true)) }
    let(:context_with_status) { double('context', status: 500) }

    describe '#errors' do
      it 'returns error.errors when error has errors and they are present' do
        payload = InteractorSupport::Concerns::Organizable::FailurePayload.new(
          error: error_with_errors,
          context: nil,
          interactor: nil,
          request_object: nil,
          params: nil,
          controller: nil,
        )
        expect(payload.errors).to(eq(error_with_errors.errors))
      end

      it 'returns context.errors when context has errors and they are present' do
        payload = InteractorSupport::Concerns::Organizable::FailurePayload.new(
          error: double('error'),
          context: context_with_errors,
          interactor: nil,
          request_object: nil,
          params: nil,
          controller: nil,
        )
        expect(payload.errors).to(eq(context_with_errors.errors))
      end

      it 'returns error message as array when error has message' do
        payload = InteractorSupport::Concerns::Organizable::FailurePayload.new(
          error: error_with_message,
          context: nil,
          interactor: nil,
          request_object: nil,
          params: nil,
          controller: nil,
        )
        expect(payload.errors).to(eq(['test message']))
      end

      it 'returns empty array when no errors or message available' do
        payload = InteractorSupport::Concerns::Organizable::FailurePayload.new(
          error: double('error'),
          context: nil,
          interactor: nil,
          request_object: nil,
          params: nil,
          controller: nil,
        )
        expect(payload.errors).to(eq([]))
      end
    end

    describe '#status' do
      it 'returns error.status when error has status' do
        payload = InteractorSupport::Concerns::Organizable::FailurePayload.new(
          error: error_with_status,
          context: nil,
          interactor: nil,
          request_object: nil,
          params: nil,
          controller: nil,
        )
        expect(payload.status).to(eq(422))
      end

      it 'returns context.status when context has status' do
        payload = InteractorSupport::Concerns::Organizable::FailurePayload.new(
          error: double('error'),
          context: context_with_status,
          interactor: nil,
          request_object: nil,
          params: nil,
          controller: nil,
        )
        expect(payload.status).to(eq(500))
      end

      it 'returns nil when neither error nor context has status' do
        payload = InteractorSupport::Concerns::Organizable::FailurePayload.new(
          error: double('error'),
          context: double('context'),
          interactor: nil,
          request_object: nil,
          params: nil,
          controller: nil,
        )
        expect(payload.status).to(be_nil)
      end
    end

    describe '#to_h' do
      it 'returns hash representation of payload' do
        payload = InteractorSupport::Concerns::Organizable::FailurePayload.new(
          error: 'test_error',
          context: 'test_context',
          interactor: 'test_interactor',
          request_object: 'test_request',
          params: { test: 'params' },
          controller: 'test_controller',
        )

        expected_hash = {
          context: 'test_context',
          error: 'test_error',
          interactor: 'test_interactor',
          request_object: 'test_request',
          params: { test: 'params' },
          handled: false,
        }

        expect(payload.to_h).to(eq(expected_hash))
      end
    end
  end

  describe 'extract_active_model_errors' do
    let(:test_controller_class) do
      Class.new do
        include InteractorSupport::Concerns::Organizable
        attr_accessor :params

        def initialize
          @params = OpenStruct.new
          def @params.permit!
            {}
          end
        end
      end
    end

    let(:test_controller) { test_controller_class.new }

    it 'extracts errors from ActiveModel::ValidationError with model' do
      model_with_errors = double('model', errors: double('errors', full_messages: ['Error 1', 'Error 2']))
      exception = double('exception', model: model_with_errors)

      result = test_controller.send(:extract_active_model_errors, exception)
      expect(result).to(eq(['Error 1', 'Error 2']))
    end

    it 'returns empty array when exception has no model' do
      exception = double('exception', model: nil)

      result = test_controller.send(:extract_active_model_errors, exception)
      expect(result).to(eq([]))
    end

    it 'returns empty array when model does not respond to errors' do
      model_without_errors = double('model')
      exception = double('exception', model: model_without_errors)

      result = test_controller.send(:extract_active_model_errors, exception)
      expect(result).to(eq([]))
    end
  end

  describe 'invoke_handler with invalid handler' do
    let(:test_controller_class) do
      Class.new do
        include InteractorSupport::Concerns::Organizable
        attr_accessor :params

        def initialize
          @params = OpenStruct.new
          def @params.permit!
            {}
          end
        end
      end
    end

    let(:test_controller) { test_controller_class.new }
    let(:failure) do
      InteractorSupport::Concerns::Organizable::FailurePayload.new(
        error: 'test',
        context: nil,
        interactor: nil,
        request_object: nil,
        params: nil,
        controller: nil,
      )
    end

    it 'raises ArgumentError for non-callable handler' do
      invalid_handler = Object.new # Object that doesn't respond to :call

      expect do
        test_controller.send(:invoke_handler, invalid_handler, failure)
      end.to(raise_error(ArgumentError, /is not callable/))
    end

    it 'handles callable object with arity' do
      callable_handler = double('callable')
      allow(callable_handler).to(receive(:respond_to?).with(:call).and_return(true))
      allow(callable_handler).to(receive(:respond_to?).with(:arity).and_return(true))
      allow(callable_handler).to(receive(:arity).and_return(1))
      allow(callable_handler).to(receive(:call).with(failure).and_return(true))

      result = test_controller.send(:invoke_handler, callable_handler, failure)
      expect(result).to(be(true))
    end

    it 'handles callable object without arity' do
      callable_handler = double('callable')
      allow(callable_handler).to(receive(:respond_to?).with(:call).and_return(true))
      allow(callable_handler).to(receive(:respond_to?).with(:arity).and_return(false))
      allow(callable_handler).to(receive(:call).with(failure).and_return(true))

      result = test_controller.send(:invoke_handler, callable_handler, failure)
      expect(result).to(be(true))
    end
  end

  describe 'resolve_error_handlers' do
    let(:test_controller_class) do
      Class.new do
        include InteractorSupport::Concerns::Organizable
        attr_accessor :params

        def initialize
          @params = OpenStruct.new
          def @params.permit!
            {}
          end
        end
      end
    end

    let(:test_controller) { test_controller_class.new }

    it 'returns empty array when custom is false' do
      result = test_controller.send(:resolve_error_handlers, false)
      expect(result).to(eq([]))
    end
  end

  describe 'emit_failure_signal_if_needed without rescue_with_handler' do
    it 'does not raise FailureHandledSignal when rescue_with_handler is not available' do
      test_controller_class = Class.new do
        include InteractorSupport::Concerns::Organizable
        attr_accessor :params, :_interactor_failure_handled

        def initialize
          @params = OpenStruct.new
          def @params.permit!
            {}
          end
          @_interactor_failure_handled = false
        end

        def handle_test_failure(failure)
          failure.handled!
        end

        # Intentionally not defining rescue_with_handler method
      end

      test_controller_class.handle_interactor_failure(:handle_test_failure)
      controller = test_controller_class.new

      # This should handle the failure but not raise FailureHandledSignal
      # because rescue_with_handler is not available
      result = controller.organize(
        FailingInteractor,
        params: {},
        request_object: SimpleRequestObject,
        halt_on_handle: true,
      )

      expect(controller.interactor_failure_handled?).to(be(true))
      expect(result).to(be_a(Interactor::Context))
      expect(result.failure?).to(be(true))
    end
  end
end
