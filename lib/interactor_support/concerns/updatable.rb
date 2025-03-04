module InteractorSupport
  module Concerns
    module Updatable
      extend ActiveSupport::Concern
      included do
        class << self
          # How It Works for Each Case:

          # update :post, attributes: { title: :title, body: :body }
          # context.post.update!(title: context.title, body: context.body)
          #
          # update :post, attributes: { title: :title, body: :body } context_key: :current_post
          # context.current_post = context.post.update!(title: context.title, body: context.body)
          #
          # update :post, attributes: { request: { title: :title, body: :body } }
          # context.post.update!(title: context.request.title, body: context.request.body), fails if context.request.nil?
          #
          # update :post, attributes: { request: [:title, :body] }
          # context.post.update!(title: context.request.title, body: context.request.body), fails if context.request.nil?
          #
          # update :post, attributes: :request
          # context.post.update!(context.request), fails if context.request.nil?

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
                      # Nested mapping (e.g., request: { title: :title, body: :body })
                      parent = context[key]
                      context.fail!(errors: ["#{key} not found"]) unless parent
                      result.merge!(value.transform_values { |v| parent[v] })
                    when Array
                      # Array mapping (e.g., request: [:title, :body])
                      parent = context[key]
                      context.fail!(errors: ["#{key} not found"]) unless parent
                      result.merge!(value.index_with { |v| parent[v] })
                    else
                      # Direct mapping (e.g., title: :title)
                      result[key] = context.send(value)
                    end
                  end
                when Symbol
                  # Direct context key (e.g., attributes: :request)
                  data = context[attributes]
                  context.fail!(errors: ["#{attributes} not found"]) unless data
                  data
                else
                  raise ArgumentError, "Invalid attributes: #{attributes}"
                end

              record.update!(update_data)

              # Assign the updated record to context
              context[context_key] = record
            end
          end
        end
      end
    end
  end
end
