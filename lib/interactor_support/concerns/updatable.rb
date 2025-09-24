module InteractorSupport
  module Concerns
    ##
    # Adds an `update` DSL for synchronizing context data back into ActiveRecord models.
    #
    # The DSL supports:
    # - Direct mappings from context keys to model attributes
    # - Plucking nested values from other context objects (hashes or structs)
    # - Lambdas for dynamic evaluation, executed in the interactor context
    # - Passing a symbol that points to a hash of attributes in the context (mass assignment)
    #
    # Each update runs before `#call` and uses `record.update!`, so failures raise immediately unless
    # rescued by the interactor.
    #
    # @example Update a user using context values
    #   update :user, attributes: { name: :new_name, email: :new_email }
    #
    # @example Extract nested fields from a context object
    #   update :user, attributes: { form_data: [:name, :email] }
    #
    # @example Use a lambda for computed value
    #   update :post, attributes: { published_at: -> { Time.current } }
    #
    # @see InteractorSupport::Actions
    module Updatable
      extend ActiveSupport::Concern
      include InteractorSupport::Core

      included do
        class << self
          # Updates a model using values from the context before the interactor runs.
          #
          # - When `attributes` is a Hash, keys are written to the record. Values can be:
          #   * Symbols (looked up on the context)
          #   * Arrays (pluck multiple keys from another context object)
          #   * Hashes (extract values from a parent context object)
          #   * Procs (executed with `instance_exec` for custom logic)
          # - When `attributes` is a Symbol, the corresponding context hash is used directly.
          #
          # Missing data triggers `context.fail!` with a helpful message so the update halts cleanly.
          #
          # @param model [Symbol] context key for the record to update
          # @param attributes [Hash, Symbol] mapping of target attributes or context hash to copy from
          # @param context_key [Symbol, nil] context key to store the updated record (defaults to `model`)
          #
          # @example Basic attribute update using context keys
          #   update :user, attributes: { name: :new_name, email: :new_email }
          #
          # @example Use a lambda for dynamic value
          #   update :post, attributes: { published_at: -> { Time.current } }
          #
          # @example Nested context value lookup from a parent object
          #   # Assuming context[:form_data] = OpenStruct.new(name: "Hi", email: "hi@example.com")
          #   update :user, attributes: { form_data: [:name, :email] }
          #
          # @example Using a symbol to fetch all attributes from another context object
          #   update :order, attributes: :order_attributes
          def update(model, attributes: {}, context_key: nil)
            context_key ||= model

            before do
              record = context[model]
              context.fail!(errors: ["#{model} not found"]) unless record

              update_data =
                case attributes
                when Hash
                  attributes.each_with_object({}) do |(key, value), result|
                    case value
                    when Hash
                      parent = context[key]
                      context.fail!(errors: ["#{key} not found"]) unless parent
                      result.merge!(value.transform_values { |v| parent[v] })
                    when Array
                      parent = context[key]
                      context.fail!(errors: ["#{key} not found"]) unless parent
                      result.merge!(value.index_with { |v| parent[v] })
                    when Proc
                      begin
                        result[key] = context.instance_exec(&value)
                      rescue StandardError => e
                        context.fail!(errors: [e.message])
                      end
                    else
                      result[key] = context.send(value)
                    end
                  end
                when Symbol
                  data = context[attributes]
                  context.fail!(errors: ["#{attributes} not found"]) unless data
                  data
                else
                  raise ArgumentError, "Invalid attributes: #{attributes}"
                end

              record.update!(update_data)

              context[context_key] = record
            end
          end
        end
      end
    end
  end
end
