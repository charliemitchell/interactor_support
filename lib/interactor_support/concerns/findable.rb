module InteractorSupport
  module Concerns
    module Findable
      extend ActiveSupport::Concern
      included do
        class << self
          # This method is a convenience method for simple find_by queries.
          # find_by :post, query: { slug: :slug }, context_key: :current_post
          # find_by :post, query: { id: :post_id, published: true }
          # find_by :post
          def find_by(model, query: {}, context_key: nil, required: false)
            context_key ||= model
            before do
              # If the query is empty, assert that the key is resource_id, eg post_id.
              if query.empty?
                id = context["#{model}_id".to_sym]
                context[context_key] = model.to_s.classify.constantize.find_by(id: id)
              else
                context[context_key] = model.to_s.classify.constantize.find_by(
                  query.transform_values do |v|
                    # If the value is a symbol, look up the value in the context.
                    # Otherwise, use the value as it is.
                    v.is_a?(Symbol) ? context[v] : v
                  end,
                )
              end
              context.fail!(errors: ["#{model} not found"]) if required && context[context_key].nil?
            end
          end

          # This method is a convenience method for simple where queries
          # find_where :post, where: { user_id: :user_id }
          # find_where :post, where: { user_id: :user_id, created_at: 5.days.ago...Time.current }
          # find_where :post, where: { user_id: :user_id }, where_not: { active: false }
          # find_where :post, where: { user_id: :user_id }, scope: :active
          # find_where :post, where: { user_id: :user_id }, context_key: :genres
          def find_where(model, where: {}, where_not: {}, scope: nil, context_key: nil, required: false)
            context_key ||= model.to_s.pluralize.to_sym
            before do
              query = model.to_s.classify.constantize
              query = query.where(
                where.transform_values do |v|
                  v.is_a?(Symbol) ? context[v] : v
                end,
              ) if where.present?

              query = query.where.not(
                where_not.transform_values do |v|
                  v.is_a?(Symbol) ? context[v] : v
                end,
              ) if where_not.present?

              query = query.send(scope) if scope.present?
              context[context_key] = query
              context.fail!(errors: ["no #{model}s were found"]) if required && context[context_key].empty?
            end
          end
        end
      end
    end
  end
end
