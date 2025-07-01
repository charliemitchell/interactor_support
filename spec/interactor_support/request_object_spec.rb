RSpec.describe(InteractorSupport::RequestObject) do
  before do
    InteractorSupport.configure do |config|
      config.request_object_behavior = :returns_self
      config.log_level = Logger::INFO
    end
  end

  describe 'transform support' do
    context 'with single transform' do
      it 'applies the transform' do
        genre = GenreRequest.new(title: '  Sci-Fi  ', description: '  Spacey stuff ')
        expect(genre.title).to(eq('Sci-Fi'))
        expect(genre.description).to(eq('Spacey stuff'))
      end
    end

    context 'with multiple transforms' do
      it 'applies them in order' do
        loc = LocationRequest.new(
          city: '  New York  ',
          country_code: '  us  ',
          state_code: '  ny  ',
          postal_code: '  10001-5432  ',
          address: '  123 Main St.  ',
        )
        expect(loc.city).to(eq('new york'))
        expect(loc.country_code).to(eq('US'))
        expect(loc.state_code).to(eq('NY'))
        expect(loc.postal_code).to(eq('10001'))
        expect(loc.address).to(eq('123 Main St.'))
      end
    end

    context 'with invalid transform method' do
      it 'raises an ArgumentError' do
        class DummyRequest
          include InteractorSupport::RequestObject
          attribute :number, transform: :strip
        end

        expect { DummyRequest.new(number: 1234) }.to(raise_error(ArgumentError))
      end
    end
  end

  describe 'type casting' do
    context 'with primitive types' do
      it 'casts to integer, float, boolean, symbol' do
        post = TypeRequest.new(
          some_integer: '1',
          some_float: '1.23',
          some_true: 'true',
          some_false: 'false',
          some_symbol: 'foo',
        )

        expect(post.some_integer).to(eq(1))
        expect(post.some_float).to(eq(1.23))
        expect(post.some_true).to(be(true))
        expect(post.some_false).to(be(false))
        expect(post.some_symbol).to(eq(:foo))
      end
    end

    context 'with array types' do
      it 'casts values inside the array' do
        post = TypeRequest.new(genres: [1, '2', :three])
        expect(post.genres).to(eq(['1', '2', 'three']))
      end

      it 'casts a range to an array' do
        post = TypeRequest.new(some_array: 1..3)
        expect(post.some_array).to(eq([1, 2, 3]))
      end
    end

    context 'with hash types' do
      it 'accepts direct hash and casts array to hash' do
        expect(TypeRequest.new(some_hash: { a: 1 }).some_hash).to(eq({ a: 1 }))
        expect(TypeRequest.new(some_hash: [[:a, 1], [:b, 2]]).some_hash).to(eq({ a: 1, b: 2 }))
      end
    end

    context 'with unsupported types' do
      it 'raises errors for unknown symbols or unsupported primitives' do
        expect { TypeRequest.new(some_unsupported: 1) }.to(raise_error(InteractorSupport::RequestObject::TypeError))
        expect do
          TypeRequest.new(some_unsupported_primitive: 1)
        end.to(raise_error(InteractorSupport::RequestObject::TypeError))
      end
    end

    context 'with custom class type' do
      it 'accepts instances and rejects classes' do
        expect(TypeRequest.new(some_class: AnyClass.new).some_class).to(be_a(AnyClass))
        expect { TypeRequest.new(some_class: AnyClass) }.to(raise_error(InteractorSupport::RequestObject::TypeError))
      end
    end
  end

  describe 'nested request objects' do
    let(:post_data) do
      {
        user_id: 1,
        title: '  My Post  ',
        content: '  Hello world  ',
        genre: { title: '  Fiction  ', description: '  Books  ' },
        authors: [
          {
            name: '  Author One  ',
            email: 'a@b.com',
            age: '30',
            location: {
              city: '  City  ',
              country_code: '  us  ',
              state_code: '  ny  ',
              postal_code: '  12345-6789  ',
              address: '  Street  ',
            },
          },
        ],
      }
    end

    it 'builds nested request objects properly' do
      post = PostRequest.new(post_data)
      expect(post).to(be_valid)
      expect(post.genre).to(be_a(GenreRequest))
      expect(post.authors.first).to(be_a(AuthorRequest))
      expect(post.authors.first.location).to(be_a(LocationRequest))
    end
  end

  describe '#to_context' do
    it 'returns a hash with deeply nested values' do
      context = PostRequest.new(
        user_id: 1,
        title: ' Title ',
        content: ' Content ',
        genre: { title: ' Fiction ', description: ' Desc ' },
        authors: [{
          name: ' Name ',
          email: 'email@test.com',
          age: '40',
          location: {
            city: ' City ',
            country_code: 'us',
            state_code: 'ny',
            postal_code: '12345-6789',
            address: ' Address ',
          },
        }],
      ).to_context

      expect(context[:title]).to(eq('Title'))
      expect(context[:genre][:title]).to(eq('Fiction'))
      expect(context[:authors].first[:location][:city]).to(eq('city'))
    end
  end

  describe 'configuration behavior' do
    it 'returns context as a hash with symbol keys' do
      InteractorSupport.configure do |config|
        config.request_object_behavior = :returns_context
        config.request_object_key_type = :symbol
      end

      context = PostRequest.new(user_id: 1)
      expect(context).to(be_a(Hash))
      expect(context).to(have_key(:user_id))
    end

    it 'returns context as a hash with string keys' do
      InteractorSupport.configure do |config|
        config.request_object_behavior = :returns_context
        config.request_object_key_type = :string
      end

      context = PostRequest.new(user_id: 1)
      expect(context).to(be_a(Hash))
      expect(context).to(have_key('user_id'))
    end

    it 'returns context as a struct' do
      InteractorSupport.configure do |config|
        config.request_object_behavior = :returns_context
        config.request_object_key_type = :struct
      end

      context = PostRequest.new(user_id: 1)
      expect(context).to(be_a(Struct))
      expect(context.user_id).to(eq(1))
    end
  end

  describe 'rewrite support' do
    it 'uses the rewritten key internally' do
      req = ImageUploadRequest.new(image: '  url  ')
      expect(req.respond_to?(:image)).to(be(false))
      expect(req.image_url).to(eq('url'))
    end

    it 'includes the rewritten key in #to_context' do
      InteractorSupport.configure do |config|
        config.request_object_key_type = :symbol
      end

      ctx = ImageUploadRequest.new(image: '  https://img.jpg  ').to_context
      expect(ctx[:image_url]).to(eq('https://img.jpg'))
    end
  end

  describe 'attribute assignment' do
    it 'raises error for unknown attributes' do
      expect { GenreRequest.new(abc: 123) }.to(raise_error(InteractorSupport::Errors::UnknownAttribute))
    end
  end

  describe '#ignore_unknown_attributes' do
    it 'ignores unknown attributes when configured' do
      req = CalendarRequest.new(
        start_date: 5.days.from_now,
        end_date: 5.days.from_now,
        unknown: 'ignore me',
      )
      expect(req.respond_to?(:unknown)).to(be(false))
      expect(req.start_date).to(be_a(Date))
      expect(req.end_date).to(be_a(Date))
    end

    it 'logs a warning when an attribute is missing' do
      expect(InteractorSupport.configuration.logger).to(
        receive(:log).with(
          InteractorSupport.configuration.log_level,
          "InteractorSupport::RequestObject ignoring unknown attribute 'unknown' for CalendarRequest.",
        ),
      )
      CalendarRequest.new(
        start_date: 5.days.from_now,
        end_date: 5.days.from_now,
        unknown: 'ignore me',
      )
    end
  end
end
