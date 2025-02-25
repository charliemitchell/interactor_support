require "action_controller"

RSpec.describe(InteractorSupport::Request) do
  describe "#call" do
    context "when the request is valid" do
      context "when params have string keys" do
        let(:request_class) do
          Class.new do
            include Interactor
            include InteractorSupport::Request

            param :name
            param :age, transform: :to_i
            param :email, transform: :downcase

            validates :name, presence: true, length: { minimum: 3 }
            validates :age, numericality: { only_integer: true }
            validates :email, email: true

            def self.name
              "TestRequest"
            end
          end
        end

        it "sets the attributes in the context" do
          params = { "name" => "John", "age" => 30, "email" => "John@john.com" }
          context = request_class.call(params)
          expect(context.attributes).to(eq(name: "John", age: 30, email: "john@john.com"))
        end
      end

      context "when params have symbol keys" do
        let(:request_class) do
          Class.new do
            include Interactor
            include InteractorSupport::Request

            param :name
            param :age, transform: :to_i
            param :email, transform: :downcase

            validates :name, presence: true, length: { minimum: 3 }
            validates :age, numericality: { only_integer: true }
            validates :email, email: true

            def self.name
              "TestRequest"
            end
          end
        end

        it "sets the attributes in the context" do
          params = { name: "John", age: 30, email: "John@john.com" }
          context = request_class.call(params)
          expect(context.attributes).to(eq(name: "John", age: 30, email: "john@john.com"))
        end
      end

      context "when the params are strong parameters" do
        let(:request_class) do
          Class.new do
            include Interactor
            include InteractorSupport::Request

            param :name
            param :age, transform: :to_i
            param :email, transform: :downcase

            validates :name, presence: true, length: { minimum: 3 }
            validates :age, numericality: { only_integer: true }
            validates :email, email: true

            def self.name
              "TestRequest"
            end
          end
        end

        it "sets the attributes in the context" do
          params = ActionController::Parameters.new(name: "John", age: 30, email: "John@john.com")
          context = request_class.call(params)
          expect(context.attributes).to(eq(name: "John", age: 30, email: "john@john.com"))
        end
      end

      context "transforms" do
        let(:params) { { name: "John", age: 30, email: "   John@john.com   " } }
        let(:expected_result) { { name: "John", age: 30, email: "john@john.com" } }

        context "when transform is an array" do
          let(:request_class) do
            Class.new do
              include Interactor
              include InteractorSupport::Request

              param :name
              param :age, transform: :to_i
              param :email, transform: [:downcase, :strip]

              validates :name, presence: true, length: { minimum: 3 }
              validates :age, numericality: { only_integer: true }
              validates :email, email: true

              def self.name
                "TestRequest"
              end
            end
          end

          it "transforms the attribute value" do
            context = request_class.call(params)
            expect(context.attributes).to(eq(expected_result))
          end
        end

        context "when transform is a symbol" do
          let(:request_class) do
            Class.new do
              include Interactor
              include InteractorSupport::Request

              param :name
              param :age, transform: :to_i
              param :email, transform: :downcase

              validates :name, presence: true, length: { minimum: 3 }
              validates :age, numericality: { only_integer: true }
              validates :email, email: true

              def self.name
                "TestRequest"
              end
            end
          end

          it "transforms the attribute value" do
            params = { name: "John", age: 30, email: "John@john.com" }
            context = request_class.call(params)
            expect(context.attributes).to(eq(expected_result))
          end
        end

        context "when transform is a proc" do
          let(:request_class) do
            Class.new do
              include Interactor
              include InteractorSupport::Request

              param :name
              param :age, transform: :to_i
              param :email, transform: ->(value) { value.downcase.strip }

              validates :name, presence: true, length: { minimum: 3 }
              validates :age, numericality: { only_integer: true }
              validates :email, email: true

              def self.name
                "TestRequest"
              end
            end
          end

          it "transforms the attribute value" do
            context = request_class.call(params)
            expect(context.attributes).to(eq(expected_result))
          end
        end
      end

      context "with custom attributes key" do
        let(:request_class) do
          Class.new do
            include Interactor
            include InteractorSupport::Request

            attributes_key :params

            param :name
            param :age, transform: :to_i
            param :email, transform: [:downcase, :strip]

            validates :name, presence: true, length: { minimum: 3 }
            validates :age, numericality: { only_integer: true }
            validates :email, email: true

            def self.name
              "TestRequest"
            end
          end
        end

        it "sets the attributes in the context" do
          context = request_class.call(name: "John", age: 30, email: " John@john.com")
          expect(context.params).to(eq(name: "John", age: 30, email: "john@john.com"))
        end
      end
    end

    context "when the request is invalid" do
      context "validations" do
        context "email" do
          context "when the email is nil" do
            let(:request_class) do
              Class.new do
                include Interactor
                include InteractorSupport::Request

                param :name
                param :age, transform: :to_i
                param :email, transform: :downcase

                validates :name, presence: true, length: { minimum: 3 }
                validates :age, numericality: { only_integer: true }
                validates :email, email: true

                def self.name
                  "TestRequest"
                end
              end
            end

            it "fails the context with errors" do
              context = request_class.call(name: "John", age: 30, email: nil)
              expect(context).to(be_a_failure)
              expect(context.errors.map(&:message)).to(eq(["is not an email"]))
            end
          end

          context "when the email is not an email" do
            let(:request_class) do
              Class.new do
                include Interactor
                include InteractorSupport::Request

                param :name
                param :age, transform: :to_i
                param :email, transform: :downcase

                validates :name, presence: true, length: { minimum: 3 }
                validates :age, numericality: { only_integer: true }
                validates :email, email: true

                def self.name
                  "TestRequest"
                end
              end
            end

            it "fails the context with errors" do
              context = request_class.call(name: "John", age: 30, email: "fooo")
              expect(context).to(be_a_failure)
              expect(context.errors.map(&:message)).to(eq(["is not an email"]))
            end
          end

          context "when the email is not a string" do
            let(:request_class) do
              Class.new do
                include Interactor
                include InteractorSupport::Request

                param :name
                param :age, transform: :to_i
                param :email

                validates :name, presence: true, length: { minimum: 3 }
                validates :age, numericality: { only_integer: true }
                validates :email, email: true

                def self.name
                  "TestRequest"
                end
              end
            end

            it "fails the context with errors" do
              context = request_class.call(name: "John", age: 30, email: 500)
              expect(context).to(be_a_failure)
              expect(context.errors.map(&:full_message)).to(eq(["Email is not an email"]))
            end
          end
        end
      end

      context "transforms" do
        let(:params) { { name: "John", age: 30, email: "   John@john.com   " } }
        let(:expected_result) { { name: "John", age: 30, email: "john@john.com" } }

        context "when transform is an array" do
          let(:request_class) do
            Class.new do
              include Interactor
              include InteractorSupport::Request

              param :name
              param :age, transform: [:downcase, :strip]
              param :email, transform: [:downcase, :strip]

              validates :name, presence: true, length: { minimum: 3 }
              validates :age, numericality: { only_integer: true }
              validates :email, email: true

              def self.name
                "TestRequest"
              end
            end
          end

          it "transforms the attribute value" do
            context = request_class.call(params)
            expect(context).to be_failure
            expect(context.errors).to(eq(["age does not respond to all transforms"]))
          end
        end

        context "when transform is a symbol" do
          let(:request_class) do
            Class.new do
              include Interactor
              include InteractorSupport::Request

              param :name
              param :age, transform: :downcase
              param :email, transform: :downcase

              validates :name, presence: true, length: { minimum: 3 }
              validates :age, numericality: { only_integer: true }
              validates :email, email: true

              def self.name
                "TestRequest"
              end
            end
          end

          it "transforms the attribute value" do
            params = { name: "John", age: 30, email: "John@john.com" }
            context = request_class.call(params)
            expect(context).to be_failure
            expect(context.errors).to(eq(["age does not respond to the given transform"]))
          end
        end

        context "when transform is a proc" do
          let(:request_class) do
            Class.new do
              include Interactor
              include InteractorSupport::Request

              param :name
              param :age, transform: :to_i
              param :email, transform: ->(value) { value.nope }

              validates :name, presence: true, length: { minimum: 3 }
              validates :age, numericality: { only_integer: true }
              validates :email, email: true

              def self.name
                "TestRequest"
              end
            end
          end

          it "transforms the attribute value" do
            context = request_class.call(params)
            expect(context).to be_failure
            expect(context.errors).to(
              eq(["email failed to transform: undefined method `nope' for \"   John@john.com   \":String"]))
          end
        end

        context "when transform is not a symbol, array, or proc" do
          let(:request_class) do
            Class.new do
              include Interactor
              include InteractorSupport::Request

              param :name
              param :age, transform: :to_i
              param :email, transform: 500

              validates :name, presence: true, length: { minimum: 3 }
              validates :age, numericality: { only_integer: true }
              validates :email, email: true

              def self.name
                "TestRequest"
              end
            end
          end

          it "fails the context with errors" do
            expect { request_class.call(params) }.to raise_error(ArgumentError)
          end
        end
      end
    end
  end
end
