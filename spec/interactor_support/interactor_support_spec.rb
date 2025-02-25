RSpec.describe InteractorSupport do
  describe '.included' do
    it 'includes all modules' do
      interactor = Class.new do
        include Interactor
        include InteractorSupport
      end

      expect(interactor.ancestors).to(include(InteractorSupport::Actions))
      expect(interactor.ancestors).to(include(InteractorSupport::Validations))
      expect(interactor.ancestors).to(include(InteractorSupport::Request))
    end
  end

  describe 'on an interactor' do
    let(:genre_class) do
      Class.new(ApplicationRecord) do
        self.table_name = "genres"
      end
    end
  
    let!(:genre) { genre_class.create!(name: "jazz") }
  
    before do
      stub_const("Genre", genre_class)
    end

    let(:interactor) do
      Class.new do
        include Interactor
        include InteractorSupport

        transaction
        transform :genre_name, :rename_genre, with: [:downcase, :strip]
        validates_before :genre_name, presence: true, inclusion: { in: %w[rock pop jazz] }
        skip if: -> { genre_name == "rock" }
        find_by :genre, query: { name: :genre_name }
        update :genre, attributes: { name: :rename_genre }
        context_variable numbers: [1, 2, 3]

        def call
          context.fail!(errors: ['context_variable failed']) if context.numbers.nil?
          context.fail!(errors: ["oh no"]) if context.raise_active_record_rollback
        end
      end
    end

    describe 'is a success' do
      it 'when the genre is found and updated' do
        context = interactor.call(genre_name: "  Jazz  ", rename_genre: " Jazzy Jazz   ")
        expect(context).to(be_success)
        expect(context.genre.name).to(eq("jazzy jazz"))
        expect(context.numbers).to(eq([1, 2, 3]))
      end
    end

    describe 'is a failure' do

      it 'when the genre is not in the inclusion' do
        context = interactor.call(genre_name: "nope", rename_genre: "nope")
        expect(context).to(be_failure)
        expect(context.errors).to(eq(["genre_name was not in the specified inclusion"]))
      end

      it 'when the genre is not found' do
        context = interactor.call(genre_name: "pop", rename_genre: "rock")
        expect(context).to(be_failure)
        expect(context.errors).to(eq(["genre not found"]))
      end

      it 'when the genre is not present' do
        context = interactor.call
        expect(context).to(be_failure)
        expect(context.errors).to(eq(["genre_name does not respond to all transforms"]))
      end

      it 'when the transaction is rolled back' do
        context = interactor.call(
          genre_name: "Jazz", 
          rename_genre: "rock", 
          raise_active_record_rollback: true
        )
        expect(context).to(be_failure)
        expect(context.errors).to(eq(["oh no"]))
        expect(genre_class.find(genre.id).name).to(eq("jazz"))
      end
    end
  end

  describe 'on an organizer' do
    let(:genre_class) do
      Class.new(ApplicationRecord) do
        self.table_name = "genres"
      end
    end
  
    let!(:genre) { genre_class.create!(name: "jazz") }
  
    before do
      stub_const("Genre", genre_class)
    end

    let(:organizer) do
      interactor = Class.new do
        include Interactor
        include InteractorSupport

        def call
          context.fail!(errors: ['context_variable failed']) if context.numbers.nil?
          context.fail!(errors: ["oh no"]) if context.raise_active_record_rollback
        end
      end

      Class.new do
        include Interactor::Organizer
        include InteractorSupport

        transaction
        transform :genre_name, :rename_genre, with: [:downcase, :strip]
        validates_before :genre_name, presence: true, inclusion: { in: %w[rock pop jazz] }
        skip if: -> { genre_name == "rock" }
        find_by :genre, query: { name: :genre_name }
        update :genre, attributes: { name: :rename_genre }
        context_variable numbers: [1, 2, 3]

        organize interactor
      end
    end

    describe 'is a success' do
      it 'when the genre is found and updated' do
        context = organizer.call(genre_name: "  Jazz  ", rename_genre: " Jazzy Jazz   ")
        expect(context).to(be_success)
        expect(context.genre.name).to(eq("jazzy jazz"))
        expect(context.numbers).to(eq([1, 2, 3]))
      end
    end

    describe 'is a failure' do

      it 'when the genre is not in the inclusion' do
        context = organizer.call(genre_name: "nope", rename_genre: "nope")
        expect(context).to(be_failure)
        expect(context.errors).to(eq(["genre_name was not in the specified inclusion"]))
      end

      it 'when the genre is not found' do
        context = organizer.call(genre_name: "pop", rename_genre: "rock")
        expect(context).to(be_failure)
        expect(context.errors).to(eq(["genre not found"]))
      end

      it 'when the genre is not present' do
        context = organizer.call
        expect(context).to(be_failure)
        expect(context.errors).to(eq(["genre_name does not respond to all transforms"]))
      end

      it 'when the transaction is rolled back' do
        context = organizer.call(
          genre_name: "Jazz", 
          rename_genre: "rock", 
          raise_active_record_rollback: true
        )
        expect(context).to(be_failure)
        expect(context.errors).to(eq(["oh no"]))
        expect(genre_class.find(genre.id).name).to(eq("jazz"))
      end
    end
  end
end