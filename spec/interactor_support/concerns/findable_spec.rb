RSpec.describe(InteractorSupport::Concerns::Findable) do
  let(:genre_class) do
    Class.new(ApplicationRecord) do
      self.table_name = "genres"
    end
  end

  let(:genre) { genre_class.create!(name: "Rock") }

  before do
    stub_const("Genre", genre_class)
  end

  describe ".find_by" do
    context "when query is empty" do
      it "finds the record by id" do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Findable

          find_by :genre
        end

        context = interactor.call(genre_id: genre.id)
        expect(context.genre).to(eq(genre))
      end
      it "fails the context if the record is not found and required is true" do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Findable

          find_by :genre, required: true
        end

        context = interactor.call(genre_id: -1)
        expect(context.success?).to(be(false))
        expect(context.errors).to(eq(["genre not found"]))
      end

      it "sets the found record to the provided context key" do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Findable

          find_by :genre, context_key: :current_genre
        end

        context = interactor.call(genre_id: genre.id)
        expect(context.current_genre).to(eq(genre))
        expect(context.genre).to(be_nil)
      end
    end

    context "when query is provided" do
      it "finds the record by the provided query" do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Findable

          find_by :genre, query: { name: :name }
        end

        context = interactor.call(name: genre.name)
        expect(context.genre).to(eq(genre))
      end
      it "fails the context if the record is not found and required is true" do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Findable

          find_by :genre, query: { name: :name }, required: true
        end

        context = interactor.call(name: "Non-existent")
        expect(context.success?).to(be(false))
        expect(context.errors).to(eq(["genre not found"]))
      end
      it "sets the found record to the provided context key" do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Findable

          find_by :genre, query: { name: :name }, context_key: :current_genre
        end

        context = interactor.call(name: genre.name)
        expect(context.current_genre).to(eq(genre))
        expect(context.genre).to(be_nil)
      end
    end
  end

  describe ".find_where" do
    context "when where clause is provided" do
      it "finds the records by the provided where clause" do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Findable

          find_where :genre, where: { name: :name }
        end

        context = interactor.call(name: genre.name)
        expect(context.genres).to(eq([genre]))
      end
      it "fails the context if no records are found and required is true" do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Findable

          find_where :genre, where: { name: :name }, required: true
        end

        context = interactor.call(name: "Non-existent")
        expect(context.success?).to(be(false))
        expect(context.errors).to(eq(["no genres were found"]))
      end
      it "sets the found records to the provided context key" do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Findable

          find_where :genre, where: { name: :name }, context_key: :genres
        end

        context = interactor.call(name: genre.name)
        expect(context.genres).to(eq([genre]))
      end
    end

    context "when where_not clause is provided" do
      it "excludes the records by the provided where_not clause" do
        pop = genre_class.create!(name: "Pop")
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Findable

          find_where :genre, where_not: { name: :name }
        end

        context = interactor.call(name: genre.name)
        expect(context.genres).to eq([pop])
      end
      it "fails the context if no records are found and required is true" do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Findable

          find_where :genre, where_not: { name: :name }, required: true
        end

        context = interactor.call(name: genre.name)
        expect(context.success?).to be(false)
        expect(context.errors).to eq(["no genres were found"])
      end
      it "sets the found records to the provided context key" do
        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Findable

          find_where :genre, where_not: { name: :name }, context_key: :genres
        end

        context = interactor.call(name: genre.name)
        expect(context.genres).to eq([])
      end
    end

    context "when scope is provided" do
      it "applies the provided scope to the query" do
        genre_class.scope(:rock, -> { where(name: "Rock") })

        interactor = Class.new do
          include Interactor
          include InteractorSupport::Concerns::Findable

          find_where :genre, scope: :rock
        end

        context = interactor.call
        expect(context.genres).to(eq([genre]))
      end
    end
  end
end
