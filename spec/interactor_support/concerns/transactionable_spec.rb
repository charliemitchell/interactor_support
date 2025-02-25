RSpec.describe(InteractorSupport::Concerns::Transactionable) do
  describe '.transaction' do

    let(:genre_class) do
      Class.new(ApplicationRecord) do
        self.table_name = 'genres'
      end
    end

    it 'wraps the interactor in a transaction' do
      interactor = Class.new do
        include Interactor
        include InteractorSupport::Concerns::Transactionable
        transaction
        def call
          context.genre_class.create!(name: 'Rock')
          raise ActiveRecord::Rollback
        end
      end

      expect { interactor.call(genre_class:) }.not_to change { genre_class.count }
    end

    it 'works with a custom isolation level' do
      interactor = Class.new do
        include Interactor
        include InteractorSupport::Concerns::Transactionable
        transaction isolation: :serializable
        def call
          context.genre_class.create!(name: 'Rock')
          raise ActiveRecord::Rollback
        end
      end

      allow(ActiveRecord::Base).to receive(:transaction).and_yield
      expect(ActiveRecord::Base).to receive(:transaction).with(hash_including(isolation: :serializable)).and_yield
      expect { interactor.call(genre_class: genre_class) }.to raise_error(ActiveRecord::Rollback)
    end

    it 'works with a custom joinable option' do
      interactor = Class.new do
        include Interactor
        include InteractorSupport::Concerns::Transactionable
        transaction joinable: false
        def call
          context.genre_class.create!(name: 'Rock')
          raise ActiveRecord::Rollback
        end
      end

      allow(ActiveRecord::Base).to receive(:transaction).and_yield
      expect(ActiveRecord::Base).to receive(:transaction).with(hash_including(joinable: false)).and_yield
      expect { interactor.call(genre_class: genre_class) }.to raise_error(ActiveRecord::Rollback)
    end

    it 'works with a custom requires_new option' do
      interactor = Class.new do
        include Interactor
        include InteractorSupport::Concerns::Transactionable
        transaction requires_new: true
        def call
          context.genre_class.create!(name: 'Rock')
          raise ActiveRecord::Rollback
        end
      end

      allow(ActiveRecord::Base).to receive(:transaction).and_yield
      expect(ActiveRecord::Base).to receive(:transaction).with(hash_including(requires_new: true)).and_yield
      expect { interactor.call(genre_class: genre_class) }.to raise_error(ActiveRecord::Rollback)
    end

    it 'works in an organizer' do
      interactor = Class.new do
        include Interactor::Organizer
        include InteractorSupport::Concerns::Transactionable
        transaction
        organize(
          Class.new do
            include Interactor
            def call
              context.genre_class.create!(name: 'Rock')
              raise ActiveRecord::Rollback
            end
          end
        )
      end
      expect { interactor.call(genre_class:) }.not_to change { genre_class.count }
    end
  end
end