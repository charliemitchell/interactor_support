# frozen_string_literal: true

RSpec.describe(InteractorSupport::Actions) do
  let(:default_interactor) do
    Class.new do
      include Interactor
      include InteractorSupport::Validations

      def call
        context.executed = true
      end
    end
  end

  context "validates_before" do
    context "type" do
      context "when the key is not of the specified type" do
        it "fails and adds an error to the context" do
          interactor = Class.new(default_interactor) do
            validates_before :foo, type: Integer
          end

          result = interactor.call(foo: "bar")
          expect(result).to(be_a_failure)
          expect(result.errors).to(include("foo was not of type Integer"))
          expect(result.executed).to(be_nil)
        end
      end
      context "when the key is of the specified type" do
        it "succeeds" do
          interactor = Class.new(default_interactor) do
            validates_before :foo, type: Integer
          end

          result = interactor.call(foo: 1)
          expect(result).to(be_a_success)
          expect(result.executed).to(be_truthy)
        end
      end
    end

    context "presence" do
      context "when the key is not present" do
        it "fails and adds an error to the context" do
          interactor = Class.new(default_interactor) do
            validates_before :foo, presence: true
          end

          result = interactor.call
          expect(result).to(be_a_failure)
          expect(result.errors).to(include("foo does not exist"))
          expect(result.executed).to(be_nil)
        end
      end
      context "when the key is present" do
        it "succeeds" do
          interactor = Class.new(default_interactor) do
            validates_before :foo, presence: true
          end

          result = interactor.call(foo: "bar")
          expect(result).to(be_a_success)
        end
      end
    end

    context "inclusion" do
      context "when the key is not in the specified list" do
        it "fails and adds an error to the context" do
          interactor = Class.new(default_interactor) do
            validates_before :foo, inclusion: { in: ["bar", "baz"] }
          end

          result = interactor.call(foo: "qux")
          expect(result).to(be_a_failure)
          expect(result.errors).to(include("foo was not in the specified inclusion"))
          expect(result.executed).to(be_nil)
        end
      end
      context "when the key is in the specified list" do
        it "succeeds" do
          interactor = Class.new(default_interactor) do
            validates_before :foo, inclusion: { in: ["bar", "baz"] }
          end

          result = interactor.call(foo: "bar")
          expect(result).to(be_a_success)
          expect(result.executed).to(be_truthy)
        end
      end
      context "when the key is in the specified range" do
        it "succeeds" do
          interactor = Class.new(default_interactor) do
            validates_before :foo, inclusion: { in: 1..10 }
          end

          result = interactor.call(foo: 5)
          expect(result).to(be_a_success)
          expect(result.executed).to(be_truthy)
        end
      end
      context "when the key is not in the specified range" do
        it "fails and adds an error to the context" do
          interactor = Class.new(default_interactor) do
            validates_before :foo, inclusion: { in: 1..10 }
          end

          result = interactor.call(foo: 11)
          expect(result).to(be_a_failure)
          expect(result.errors).to(include("foo was not in the specified inclusion"))
          expect(result.executed).to(be_nil)
        end
      end
      context "when the inclusion params are not a range or array" do
        it "fails and adds an error to the context" do
          interactor = Class.new(default_interactor) do
            validates_before :foo, inclusion: { in: "foo" }
          end

          result = interactor.call(foo: "bar")
          expect(result).to(be_a_failure)
          expect(result.errors).to(include("inclusion validation requires an array or range of values"))
          expect(result.executed).to(be_nil)
        end
      end
      context "when passing a raw value" do
        it "fails and adds an error to the context" do
          interactor = Class.new(default_interactor) do
            validates_before :foo, inclusion: ["bar", "baz"]
          end

          result = interactor.call(foo: "bar")
          expect(result).to(be_a_failure)
          expect(result.errors).to(include("inclusion validation requires an inclusion hash"))
          expect(result.executed).to(be_nil)
        end
      end
      context "when the inclusion hash is missing the :in key" do
        it "fails and adds an error to the context" do
          interactor = Class.new(default_interactor) do
            validates_before :foo, inclusion: {}
          end

          result = interactor.call(foo: "bar")
          expect(result).to(be_a_failure)
          expect(result.errors).to(include("inclusion validation requires an :in key"))
          expect(result.executed).to(be_nil)
        end
      end
    end

    context "persisted" do
      it "fails and adds an error to the context" do
        interactor = Class.new(default_interactor) do
          validates_before :foo, persisted: true
        end

        result = interactor.call
        expect(result).to(be_a_failure)
        expect(result.errors).to(include("persisted validation is only available for after validations"))
        expect(result.executed).to(be_nil)
      end
    end
  end

  context "validates_after" do
    context "type" do
      context "when the key is not of the specified type" do
        it "fails and adds an error to the context" do
          interactor = Class.new(default_interactor) do
            validates_after :executed, type: String
          end

          result = interactor.call
          expect(result).to(be_a_failure)
          expect(result.errors).to(include("executed was not of type String"))
        end
      end
      context "when the key is of the specified type" do
        it "succeeds" do
          interactor = Class.new(default_interactor) do
            validates_after :foo, type: Integer
          end

          result = interactor.call(foo: 1)
          expect(result).to(be_a_success)
          expect(result.executed).to(be_truthy)
        end
      end
    end

    context "presence" do
      context "when the key is not present" do
        it "fails and adds an error to the context" do
          interactor = Class.new(default_interactor) do
            validates_after :foo, presence: true
          end

          result = interactor.call
          expect(result).to(be_a_failure)
          expect(result.errors).to(include("foo does not exist"))
        end
      end
      context "when the key is present" do
        it "succeeds" do
          interactor = Class.new(default_interactor) do
            validates_after :foo, presence: true
          end

          result = interactor.call(foo: "bar")
          expect(result).to(be_a_success)
        end
      end
    end

    context "inclusion" do
      context "when the key is not in the specified list" do
        it "fails and adds an error to the context" do
          interactor = Class.new(default_interactor) do
            validates_after :foo, inclusion: { in: ["bar", "baz"] }
          end

          result = interactor.call(foo: "qux")
          expect(result).to(be_a_failure)
          expect(result.errors).to(include("foo was not in the specified inclusion"))
        end
      end
      context "when the key is in the specified list" do
        it "succeeds" do
          interactor = Class.new(default_interactor) do
            validates_after :foo, inclusion: { in: ["bar", "baz"] }
          end

          result = interactor.call(foo: "bar")
          expect(result).to(be_a_success)
        end
      end
      context "when the key is in the specified range" do
        it "succeeds" do
          interactor = Class.new(default_interactor) do
            validates_after :foo, inclusion: { in: 1..10 }
          end

          result = interactor.call(foo: 5)
          expect(result).to(be_a_success)
        end
      end
      context "when the key is not in the specified range" do
        it "fails and adds an error to the context" do
          interactor = Class.new(default_interactor) do
            validates_after :foo, inclusion: { in: 1..10 }
          end

          result = interactor.call(foo: 11)
          expect(result).to(be_a_failure)
          expect(result.errors).to(include("foo was not in the specified inclusion"))
        end
      end
      context "when the inclusion params are not a range or array" do
        it "fails and adds an error to the context" do
          interactor = Class.new(default_interactor) do
            validates_after :foo, inclusion: { in: "foo" }
          end

          result = interactor.call(foo: "bar")
          expect(result).to(be_a_failure)
          expect(result.errors).to(include("inclusion validation requires an array or range of values"))
        end
      end
      context "when passing a raw value" do
        it "fails and adds an error to the context" do
          interactor = Class.new(default_interactor) do
            validates_after :foo, inclusion: ["bar", "baz"]
          end

          result = interactor.call(foo: "bar")
          expect(result).to(be_a_failure)
          expect(result.errors).to(include("inclusion validation requires an inclusion hash"))
        end
      end
      context "when the inclusion hash is missing the :in key" do
        it "fails and adds an error to the context" do
          interactor = Class.new(default_interactor) do
            validates_after :foo, inclusion: {}
          end

          result = interactor.call(foo: "bar")
          expect(result).to(be_a_failure)
          expect(result.errors).to(include("inclusion validation requires an :in key"))
        end
      end
    end

    context "persisted" do
      let(:genre_class) do
        Class.new(ApplicationRecord) do
          self.table_name = "genres"
        end
      end

      let(:persisted_genre) { genre_class.create(name: "foo") }
      let(:unpersisted_genre) { genre_class.new(name: "bar") }

      context "when the key is not persisted" do
        it "fails and adds an error to the context" do
          interactor = Class.new(default_interactor) do
            validates_after :unpersisted_genre, persisted: true
          end

          result = interactor.call(unpersisted_genre: unpersisted_genre)
          expect(result).to(be_a_failure)
          expect(result.errors).to(include("unpersisted_genre was not persisted"))
        end
      end
      context "when the key is persisted" do
        it "succeeds" do
          interactor = Class.new(default_interactor) do
            validates_after :persisted_genre, persisted: true
          end

          result = interactor.call(persisted_genre: persisted_genre)
          expect(result).to(be_a_success)
          expect(result.executed).to(be_truthy)
        end
      end
    end
  end

  context "required" do
    context "when the key is not present" do
      it "fails and adds an error to the context" do
        interactor = Class.new(default_interactor) do
          required :foo
        end

        result = interactor.call
        expect(result).to(be_a_failure)
        expect(result.errors).to(include("foo is required"))
        expect(result.executed).to(be_nil)
      end
    end
    context "when multiple keys are missing" do
      it "fails and adds an error to the context for each missing key" do
        interactor = Class.new(default_interactor) do
          required :foo, :bar
        end

        result = interactor.call
        expect(result).to(be_a_failure)
        expect(result.errors).to(include("foo is required"))
        expect(result.errors).to(include("bar is required"))
        expect(result.executed).to(be_nil)
      end
    end

    context "when the key is present" do
      it "succeeds" do
        interactor = Class.new(default_interactor) do
          required :foo
        end

        result = interactor.call(foo: "bar")
        expect(result).to(be_a_success)
        expect(result.executed).to(be_truthy)
      end

      it "sets the attr_accessor" do
        interactor = Class.new(default_interactor) do
          required :foo

          def call
            raise "foo is not set" unless foo
          end
        end

        result = interactor.call(foo: "bar")
        expect(result).to(be_a_success)
      end
    end
  end

  context "optional" do
    context "when the key is not present" do
      it "succeeds" do
        interactor = Class.new(default_interactor) do
          optional :foo
        end

        result = interactor.call
        expect(result).to(be_a_success)
        expect(result.executed).to(be_truthy)
      end
    end

    context "when the key is present" do
      it "succeeds" do
        interactor = Class.new(default_interactor) do
          optional :foo
        end

        result = interactor.call(foo: "bar")
        expect(result).to(be_a_success)
        expect(result.executed).to(be_truthy)
      end
      it "sets the attr_accessor" do
        interactor = Class.new(default_interactor) do
          optional :foo

          def call
            raise "foo is not set" unless foo
          end
        end

        result = interactor.call(foo: "bar")
        expect(result).to(be_a_success)
      end
    end
  end
end
