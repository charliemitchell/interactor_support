RSpec.describe(InteractorSupport::Concerns::Transformable) do
  let(:genre_class) do
    Class.new(ApplicationRecord) do
      self.table_name = "genres"
    end
  end

  let!(:genres) do 
    genre_class.create!(name: "Rock")
    genre_class.create!(name: "Pop")
    genre_class.create!(name: "Jazz")
  end

  before do
    stub_const("Genre", genre_class)
  end


  describe '.context_variable' do
    it 'the context variables are available within the call method' do
      interactor = Class.new do
        include Interactor
        include InteractorSupport::Concerns::Transformable

        context_variable first_genre: Genre.first
        context_variable rock: -> { Genre.find_by(name: genre_name) }
        context_variable genres: Genre.all
        context_variable numbers: [1, 2, 3]

        def call
          context.fail!(errors: ['context_variable failed']) if context.first_genre.nil?
          context.fail!(errors: ['context_variable failed']) if context.rock.nil?
          context.fail!(errors: ['context_variable failed']) if context.genres.nil?
          context.fail!(errors: ['context_variable failed']) if context.numbers.nil?
        end
      end

      expect { interactor.call(genre_name: "Rock") }.not_to raise_error
    end

    it 'the context variables are available on the context' do
      interactor = Class.new do
        include Interactor
        include InteractorSupport::Concerns::Transformable

        context_variable first_genre: Genre.first
        context_variable rock: -> { Genre.find_by(name: genre_name) }
        context_variable genres: Genre.all
        context_variable numbers: [1, 2, 3]
      end

      context = interactor.call(genre_name: "Rock")
      expect(context.first_genre).to(eq(Genre.first))
      expect(context.rock).to(eq(Genre.find_by(name: "Rock")))
      expect(context.genres).to(eq(Genre.all))
      expect(context.numbers).to(eq([1, 2, 3]))
    end

    it 'using a proc will ensure that the value is obtained only the the interactor is called' do
      interactor = Class.new do
        include Interactor
        include InteractorSupport::Concerns::Transformable
        context_variable rock: -> { Genre.find_by(name: genre_name) }
      end

      Genre.find_by(name: "Rock").destroy
      context = interactor.call(genre_name: "Rock")
      expect(context.first_genre).to(eq(nil))
    end

    it 'directly setting the value will set the value at the time of definition' do
      interactor = Class.new do
        include Interactor
        include InteractorSupport::Concerns::Transformable
        context_variable rock: Genre.find_by(name: "Rock")
      end

      rock = Genre.find_by(name: "Rock").destroy
      context = interactor.call
      expect(context.rock).to(eq(rock))
    end
  end

  describe "#transform" do
    context "when no keys are provided" do
      it "raises an ArgumentError" do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Transformable

          transform with: :downcase
        end

        expect { interactor.call }.to raise_error(ArgumentError, "transform action requires at least one key.")
      end
    end

    context "when transforming with a symbol method" do
      context "when the key responds to the method" do
        it "applies the transformation" do
          interactor = Class.new do
            include Interactor
            include InteractorSupport::Concerns::Transformable

            transform :name, with: :downcase
          end

          context = interactor.call(name: "ROCK")
          expect(context.name).to(eq("rock"))
        end
      end

      context "when the key does not respond to the method" do
        it "fails the context with an error message" do
          interactor = Class.new do
            include Interactor
            include InteractorSupport::Concerns::Transformable

            transform :name, with: :downcase
          end

          context = interactor.call(name: 1)
          expect(context.success?).to(eq(false))
          expect(context.errors).to(eq(["name does not respond to downcase"]))
        end
      end
    end

    context "when transforming with multiple symbol methods" do
      context "when the key responds to all methods" do
        it "applies all transformations in order" do
          interactor = Class.new do
            include Interactor
            include InteractorSupport::Concerns::Transformable

            transform :name, with: [:downcase, :strip, :upcase]
          end

          context = interactor.call(name: " ROCK ")
          expect(context.name).to(eq("ROCK"))
        end
      end

      context "when the key does not respond to at least one method" do
        it "fails the context with an error message" do
          interactor = Class.new do
            include Interactor
            include InteractorSupport::Concerns::Transformable

            transform :name, with: [:downcase, :strip, :nope]
          end

          context = interactor.call(name: " Hello ")
          expect(context.success?).to(eq(false))
          expect(context.errors).to(eq(["name does not respond to all transforms"]))
        end
      end
    end

    context "when transforming with a Proc" do
      it "applies the transformation using the Proc" do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Transformable

          transform :name, with: -> { name.downcase.strip }
        end

        context = interactor.call(name: " ROCK ")
        expect(context.name).to(eq("rock"))
      end

      context "when the Proc raises an error" do
        it "fails the context with an error message" do
          interactor = Class.new do
            include Interactor
            include InteractorSupport::Concerns::Transformable

            transform :name, with: -> { raise "error" }
          end

          context = interactor.call(name: " ROCK ")
          expect(context.success?).to(eq(false))
          expect(context.errors).to(eq(["name failed to transform: error"]))
        end
      end
    end

    context "when transform key is invalid" do
      it "raises an ArgumentError" do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Transformable

          transform :nope, with: 500
        end

        expect{interactor.call(name: " ROCK ")}.to raise_error(ArgumentError, "transform requires `with` to be a symbol or array of symbols.")
        
      end
    end

    context "when applying transformations to multiple keys" do
      it "applies the transformations to all specified keys" do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Transformable

          transform :name, :genre, with: [:downcase, :strip]
        end

        context = interactor.call(name: " ROCK ", genre: "POP")
        expect(context.name).to(eq("rock"))
        expect(context.genre).to(eq("pop"))
      end
    end
  end
end