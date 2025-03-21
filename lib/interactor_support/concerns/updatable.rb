module InteractorSupport
  module Concerns
    module Updatable
      extend ActiveSupport::Concern
      include InteractorSupport::Core

      included do
        class << self
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

              # Assign the updated record to context
              context[context_key] = record
            end
          end
        end
      end
    end
  end
end
