# Dummy request objects for testing purposes.

class GenreRequest
  include InteractorSupport::RequestObject

  attribute :title, transform: :strip
  attribute :description, transform: :strip

  validates :title, :description, presence: true
end

class LocationRequest
  include InteractorSupport::RequestObject

  attribute :city, transform: [:downcase, :strip]
  attribute :country_code, transform: [:strip, :upcase]
  attribute :state_code, transform: [:strip, :upcase]
  attribute :postal_code, transform: [:strip, :clean_postal_code]
  attribute :address, transform: :strip

  validates :city, :postal_code, :address, presence: true
  validates :country_code, :state_code, presence: true, length: { is: 2 }

  def clean_postal_code(value)
    value.to_s.gsub(/\D/, '')
    value.first(5)
  end
end

class AuthorRequest
  include InteractorSupport::RequestObject

  attribute :name, transform: :strip
  attribute :email, transform: [:strip, :downcase]
  attribute :age, transform: :to_i
  attribute :location, type: LocationRequest
  validates_format_of :email, with: URI::MailTo::EMAIL_REGEXP
end

class PostRequest
  include InteractorSupport::RequestObject

  attribute :user_id
  attribute :title, transform: :strip
  attribute :content, transform: :strip
  attribute :genre, type: GenreRequest
  attribute :authors, type: AuthorRequest, array: true
end

RSpec.describe(InteractorSupport::RequestObject) do
  describe 'attribute transformation' do
    before do
      InteractorSupport.configure do |config|
        config.request_object_behavior = :returns_self
      end
    end
    context 'when using a single transform' do
      it 'strips the value for a symbol transform' do
        genre = GenreRequest.new(title: '  Science Fiction  ', description: ' A genre of speculative fiction  ')
        expect(genre.title).to(eq('Science Fiction'))
        expect(genre.description).to(eq('A genre of speculative fiction'))
      end
    end

    context 'when using an array of transforms' do
      it 'applies all transform methods in order' do
        buyer = LocationRequest.new(
          city: '  New York  ',
          country_code: '  us  ',
          state_code: '  ny  ',
          postal_code: '  10001-5432  ',
          address: '  123 Main St.  ',
        )
        expect(buyer.city).to(eq('new york'))
        expect(buyer.country_code).to(eq('US'))
        expect(buyer.state_code).to(eq('NY'))
        expect(buyer.postal_code).to(eq('10001'))
        expect(buyer.address).to(eq('123 Main St.'))
      end
    end

    context 'when the value does not respond to a transform method' do
      it 'raises and argument error if the transform method is not defined' do
        class DummyRequest
          include InteractorSupport::RequestObject
          attribute :number, transform: :strip
          validates :number, presence: true
        end

        expect { DummyRequest.new(number: 1234) }.to(raise_error(ArgumentError))
      end
    end
  end

  describe 'nesting request objects and array support' do
    before do
      InteractorSupport.configure do |config|
        config.request_object_behavior = :returns_self
      end
    end
    context 'when using a type without array' do
      it "wraps the given hash in the type's new instance" do
        post = PostRequest.new(
          user_id: 1,
          title: '  My First Post  ',
          content: '  This is the content of my first post  ',
          genre: { title: '  Science Fiction  ', description: ' A genre of speculative fiction  ' },
          authors: [
            {
              name: '  John Doe  ',
              email: 'me@mail.com',
              age: '  25  ',
              location: {
                city: '  New York  ',
                country_code: '  us  ',
                state_code: '  ny  ',
                postal_code: '  10001-5432  ',
                address: '  123 Main St.  ',
              },
            },
            {
              name: '  Jane Doe  ',
              email: 'you@mail.com',
              age: '  25  ',
              location: {
                city: '  Los Angeles  ',
                country_code: '  us  ',
                state_code: '  ca  ',
                postal_code: '  90001  ',
                address: '  456 Elm St.  ',
              },
            },
          ],
        )

        expect(post).to(be_valid)
        expect(post.user_id).to(eq(1))
        expect(post.title).to(eq('My First Post'))
        expect(post.content).to(eq('This is the content of my first post'))
        expect(post.genre).to(be_a(GenreRequest))
        expect(post.genre.title).to(eq('Science Fiction'))
        expect(post.genre.description).to(eq('A genre of speculative fiction'))
        expect(post.authors).to(be_an(Array))
        expect(post.authors.size).to(eq(2))
        post.authors.each do |author|
          expect(author).to(be_a(AuthorRequest))
          expect(author).to(be_valid)
          expect(author.location).to(be_a(LocationRequest))
          expect(author.location).to(be_valid)
          expect(author.location.city).to(be_in(['new york', 'los angeles']))
          expect(author.location.country_code).to(eq('US'))
          expect(author.location.state_code).to(be_in(['NY', 'CA']))
          expect(author.location.postal_code).to(be_in(['10001', '90001']))
          expect(author.location.address).to(be_in(['123 Main St.', '456 Elm St.']))
        end
      end
    end
  end

  describe 'to_context' do
    before do
      InteractorSupport.configure do |config|
        config.request_object_behavior = :returns_self
      end
    end
    it 'returns a struct and includes nested attributes' do
      context = PostRequest.new(
        user_id: 1,
        title: '  My First Post  ',
        content: '  This is the content of my first post  ',
        genre: { title: '  Science Fiction  ', description: ' A genre of speculative fiction  ' },
        authors: [
          {
            name: '  John Doe  ',
            email: 'a@b.com',
            age: '  25  ',
            location: {
              city: '  New York  ',
              country_code: '  us  ',
              state_code: '  ny  ',
              postal_code: '  10001-5432  ',
              address: '  123 Main St.  ',
            },
          },
        ],
      ).to_context

      expect(context).to(be_a(Hash))
      expect(context[:user_id]).to(eq(1))
      expect(context[:title]).to(eq('My First Post'))
      expect(context[:content]).to(eq('This is the content of my first post'))
      expect(context[:genre]).to(be_a(Hash))
      expect(context.dig(:genre, :title)).to(eq('Science Fiction'))
      expect(context.dig(:genre, :description)).to(eq('A genre of speculative fiction'))
      expect(context[:authors]).to(be_an(Array))
      expect(context[:authors].size).to(eq(1))
      author = context[:authors].first
      expect(author).to(be_a(Hash))
      expect(author[:name]).to(eq('John Doe'))
      expect(author[:email]).to(eq('a@b.com'))
      expect(author[:age]).to(eq(25))
      expect(author[:location]).to(be_a(Hash))
      expect(author[:location][:city]).to(eq('new york'))
      expect(author[:location][:country_code]).to(eq('US'))
    end
  end

  describe 'configured request object behavior' do
    it 'returns a context hash with symbol keys when configured to do so' do
      InteractorSupport.configure do |config|
        config.request_object_behavior = :returns_context
        config.request_object_key_type = :symbol
      end

      context = PostRequest.new(
        user_id: 1,
        title: '  My First Post  ',
        content: '  This is the content of my first post  ',
        genre: { title: '  Science Fiction  ', description: ' A genre of speculative fiction  ' },
        authors: [
          {
            name: '  John Doe  ',
            email: 'j@j.com',
            age: '  25  ',
            location: {
              city: '  New York  ',
              country_code: '  us  ',
              state_code: '  ny  ',
              postal_code: '  10001-5432  ',
              address: '  123 Main St.  ',
            },
          },
        ],
      )

      expect(context).to(be_a(Hash))
      expect(context[:user_id]).to(eq(1))
      expect(context[:title]).to(eq('My First Post'))
      expect(context[:content]).to(eq('This is the content of my first post'))
      expect(context[:genre]).to(be_a(Hash))
      expect(context.dig(:genre, :title)).to(eq('Science Fiction'))
      expect(context.dig(:genre, :description)).to(eq('A genre of speculative fiction'))
      expect(context[:authors]).to(be_an(Array))
      expect(context[:authors].size).to(eq(1))
      author = context[:authors].first
      expect(author).to(be_a(Hash))
      expect(author[:name]).to(eq('John Doe'))
      expect(author[:email]).to(eq('j@j.com'))
      expect(author[:age]).to(eq(25))
      expect(author[:location]).to(be_a(Hash))
      expect(author[:location][:city]).to(eq('new york'))
      expect(author[:location][:country_code]).to(eq('US'))
    end

    it 'returns a context hash with string keys when configured to do so' do
      InteractorSupport.configure do |config|
        config.request_object_behavior = :returns_context
        config.request_object_key_type = :string
      end

      post = PostRequest.new(
        user_id: 1,
        title: '  My First Post  ',
        content: '  This is the content of my first post  ',
        genre: { title: '  Science Fiction  ', description: ' A genre of speculative fiction  ' },
        authors: [
          {
            name: '  John Doe  ',
            email: 'j@j.com',
            age: '  25  ',
            location: {
              city: '  New York  ',
              country_code: '  us  ',
              state_code: '  ny  ',
              postal_code: '  10001-5432  ',
              address: '  123 Main St.  ',
            },
          },
        ],
      )

      context = post
      expect(context).to(be_a(Hash))
      expect(context['user_id']).to(eq(1))
      expect(context['title']).to(eq('My First Post'))
      expect(context['content']).to(eq('This is the content of my first post'))
      expect(context['genre']).to(be_a(Hash))
      expect(context.dig('genre', 'title')).to(eq('Science Fiction'))
      expect(context.dig('genre', 'description')).to(eq('A genre of speculative fiction'))
      expect(context['authors']).to(be_an(Array))
      expect(context['authors'].size).to(eq(1))
      author = context['authors'].first
      expect(author).to(be_a(Hash))
      expect(author['name']).to(eq('John Doe'))
      expect(author['email']).to(eq('j@j.com'))
      expect(author['age']).to(eq(25))
      expect(author['location']).to(be_a(Hash))
      expect(author['location']['city']).to(eq('new york'))
      expect(author['location']['country_code']).to(eq('US'))
    end

    it 'returns a context struct when configured to do so' do
      InteractorSupport.configure do |config|
        config.request_object_behavior = :returns_context
        config.request_object_key_type = :struct
      end

      post = PostRequest.new(
        user_id: 1,
        title: '  My First Post  ',
        content: '  This is the content of my first post  ',
        genre: { title: '  Science Fiction  ', description: ' A genre of speculative fiction  ' },
        authors: [
          {
            name: '  John Doe  ',
            email: 'j@j.com',
            age: '  25  ',
            location: {
              city: '  New York  ',
              country_code: '  us  ',
              state_code: '  ny  ',
              postal_code: '  10001-5432  ',
              address: '  123 Main St.  ',
            },
          },
        ],
      )

      context = post
      expect(context).to(be_a(Struct))
      expect(context.user_id).to(eq(1))
      expect(context.title).to(eq('My First Post'))
      expect(context.content).to(eq('This is the content of my first post'))
      expect(context.genre).to(be_a(Struct))
      expect(context.genre.title).to(eq('Science Fiction'))
      expect(context.genre.description).to(eq('A genre of speculative fiction'))
      expect(context.authors).to(be_an(Array))
      expect(context.authors.size).to(eq(1))
      author = context.authors.first
      expect(author).to(be_a(Struct))
      expect(author.name).to(eq('John Doe'))
      expect(author.email).to(eq('j@j.com'))
      expect(author.age).to(eq(25))
      expect(author.location).to(be_a(Struct))
      expect(author.location.city).to(eq('new york'))
      expect(author.location.country_code).to(eq('US'))
    end
  end
end
