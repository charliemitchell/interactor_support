module InteractorSupport
  module Concerns
    module Findable
      extend ActiveSupport::Concern

      included do
        class << self
          # This method finds a single record using query parameters.
          # Supports symbols (context keys) and lambdas for dynamic values.
          #
          # Examples:
          # find_by :post, query: { slug: :slug }, context_key: :current_post
          # find_by :post, query: { id: :post_id, published: true }
          # find_by :post, query: { created_at: -> { 1.week.ago..Time.current } }
          def find_by(model, query: {}, context_key: nil, required: false)
            context_key ||= model
            before do
              record =
                if query.empty?
                  id = context["#{model}_id".to_sym]
                  model.to_s.classify.constantize.find_by(id: id)
                else
                  model.to_s.classify.constantize.find_by(
                    query.transform_values do |v|
                      case v
                      when Symbol then context[v] # Lookup symbol in context
                      when Proc then instance_exec(&v) # Evaluate lambda dynamically
                      else v # Use raw value
                      end
                    end,
                  )
                end

              context[context_key] = record
              context.fail!(errors: ["#{model} not found"]) if required && record.nil?
            end
          end

          # This method finds multiple records using where conditions.
          # Supports symbols (context keys) and lambdas for dynamic values.
          #
          # Examples:
          # find_where :post, where: { user_id: :user_id }
          # find_where :post, where: { created_at: -> { 5.days.ago..Time.current } }
          # find_where :post, where: { user_id: :user_id }, where_not: { active: false }
          # find_where :post, where: { user_id: :user_id }, scope: :active
          def find_where(model, where: {}, where_not: {}, scope: nil, context_key: nil, required: false)
            context_key ||= model.to_s.pluralize.to_sym
            before do
              query = model.to_s.classify.constantize

              query = query.where(
                where.transform_values do |v|
                  case v
                  when Symbol then context[v] # Lookup symbol in context
                  when Proc then instance_exec(&v) # Evaluate lambda dynamically
                  else v # Use raw value
                  end
                end,
              ) if where.present?

              query = query.where.not(
                where_not.transform_values do |v|
                  case v
                  when Symbol then context[v]
                  when Proc then instance_exec(&v)
                  else v
                  end
                end,
              ) if where_not.present?

              query = query.send(scope) if scope.present?

              context[context_key] = query
              context.fail!(errors: ["no #{model}s were found"]) if required && query.empty?
            end
          end
        end
      end
    end
  end
end
