# frozen_string_literal: true

class DummyRequestObject
  include InteractorSupport::RequestObject

  attribute :order, :metadata, :flags, :internal, :custom
  attribute :id, :secret, :source, :location
  attribute :ip, :foo, :debug
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

RSpec.describe(InteractorSupport::Concerns::Organizable) do
  let(:test_class) do
    Class.new do
      include InteractorSupport::Concerns::Organizable

      attr_accessor :params

      def initialize(params)
        @params = params
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
  end
end
