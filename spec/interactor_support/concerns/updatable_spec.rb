RSpec.describe(InteractorSupport::Concerns::Updatable) do
  let(:genre_class) do
    Class.new(ApplicationRecord) do
      self.table_name = 'genres'
    end
  end

  let(:genre) { genre_class.create!(name: 'Rock') }

  before do
    stub_const('Genre', genre_class)
  end

  describe 'when updating a record' do
    context 'with direct attribute mapping' do
      it 'updates the record with values from context' do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Updatable

          update :genre, attributes: { name: :name }
        end

        context = interactor.call(name: 'Pop', genre: genre)
        expect(context.genre.name).to(eq('Pop'))
      end
    end

    context 'with a context key provided' do
      it 'updates the record with values from context' do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Updatable

          update :genre, attributes: { name: :name }, context_key: :genre_update
        end

        context = interactor.call(name: 'Pop', genre: genre)
        expect(context.genre_update.name).to(eq('Pop'))
      end
    end
  end

  describe 'when attributes include nested hashes' do
    context 'with request containing key mappings' do
      it 'updates the record using values from the nested request object' do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Updatable

          update :genre, attributes: { request: { name: :name } }
        end

        context = interactor.call(request: { name: 'Pop' }, genre: genre)
        expect(context.genre.name).to(eq('Pop'))
      end
      it 'fails if the request object is nil' do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Updatable

          update :genre, attributes: { request: { name: :name } }
        end

        context = interactor.call(genre: genre)
        expect(context.errors).to(eq(['request not found']))
      end
    end

    context 'with request containing an array of keys' do
      it 'updates the record using values from the request object' do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Updatable

          update :genre, attributes: { request: [:name] }
        end

        context = interactor.call(request: { name: 'Pop' }, genre: genre)
        expect(context.genre.name).to(eq('Pop'))
      end
      it 'fails if the request object is nil' do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Updatable

          update :genre, attributes: { request: [:name] }
        end

        context = interactor.call(genre: genre)
        expect(context.errors).to(eq(['request not found']))
      end
    end
  end

  describe 'when attributes are a symbol' do
    context 'with attributes as a direct context key' do
      it 'updates the record using values from the request object' do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Updatable

          update :genre, attributes: :request
        end

        context = interactor.call(request: { name: 'Heavy Metal' }, genre: genre)
        expect(context.genre.name).to(eq('Heavy Metal'))
      end
      it 'fails if the request object is nil' do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Updatable

          update :genre, attributes: :request
        end

        context = interactor.call(genre: genre)
        expect(context.errors).to(eq(['request not found']))
      end
    end
  end

  describe 'when attributes are a lambda' do
    context 'with a lambda attribute' do
      it 'updates the record using a dynamically evaluated lambda' do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Updatable

          update :genre, attributes: { updated_at: -> { Time.current } }
        end

        context = interactor.call(genre: genre)
        expect(context.genre.updated_at).to(be_within(1.second).of(Time.current))
      end
    end

    context 'when a lambda attribute raises an error' do
      it 'fails with an appropriate error message' do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Updatable

          update :genre, attributes: { updated_at: -> { raise 'Something went wrong' } }
        end

        context = interactor.call(genre: genre)
        expect(context).to(be_failure)
        expect(context.errors).to(eq(['Something went wrong']))
      end
    end

    context 'when a lambda attribute depends on the context' do
      it 'uses the provided context values inside the lambda' do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Updatable

          update :genre, attributes: { name: -> { "Updated #{prefix}" } }
        end

        context = interactor.call(genre: genre, prefix: 'Genre')
        expect(context.genre.name).to(eq('Updated Genre'))
      end
    end
  end

  describe 'when attributes are invalid' do
    it 'fails with an error message' do
      interactor = Class.new do
        include Interactor
        include InteractorSupport::Concerns::Updatable

        update :genre, attributes: [:name]
      end

      expect { interactor.call(name: 'Pop', genre: genre) }.to(raise_error(ArgumentError))
    end
  end

  describe 'when the record does not exist in context' do
    it 'fails with an error message' do
      interactor = Class.new do
        include Interactor
        include InteractorSupport::Concerns::Updatable

        update :genre, attributes: { name: :name }
      end

      context = interactor.call(name: 'Pop')
      expect(context.errors).to(eq(['genre not found']))
    end
  end

  describe 'when required values are missing' do
    context 'when the request object is nil' do
      it 'fails with an error message' do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Updatable

          update :genre, attributes: { request: { name: :name } }
        end

        context = interactor.call(genre: genre)
        expect(context.errors).to(eq(['request not found']))
      end
    end

    context 'when the model itself is nil' do
      it 'fails with an error message' do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Updatable

          update :genre, attributes: { name: :name }
        end

        context = interactor.call(name: 'Pop', genre: nil)
        expect(context.errors).to(eq(['genre not found']))
      end
    end
  end
end
