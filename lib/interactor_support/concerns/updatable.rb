module InteractorSupport
  module Concerns
    ##
    # Adds an `update` DSL method for updating a context-loaded model with attributes.
    #
    # This concern allows flexible updates using data from the interactor's context.
    # It supports direct mapping from context keys, nested attribute extraction from parent objects,
    # lambdas for dynamic evaluation, or passing a symbol pointing to an entire context object.
    #
    # This is useful for updating records cleanly and consistently in declarative steps.
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
          # Supports flexible ways of specifying attributes:
          # - A hash mapping attribute names to context keys, nested keys, or lambdas
          # - A symbol pointing to a hash in context
          #
          # If the record or required data is missing, the context fails with an error.
          #
          # @param model [Symbol] the key in the context holding the record to update
          # @param attributes [Hash, Symbol] a hash mapping attributes to context keys/lambdas, or a symbol pointing to a context hash
          # @param context_key [Symbol, nil] key to assign the updated record to in context (defaults to `model`)
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
