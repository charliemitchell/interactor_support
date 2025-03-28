module InteractorSupport
  module Concerns
    ##
    # Adds dynamic model-finding helpers (`find_by`, `find_where`) to an interactor.
    #
    # This concern wraps ActiveRecord `.find_by` and `.where` queries into
    # declarative DSL methods that load records into the interactor context.
    #
    # These methods support symbols (for context keys) and lambdas (for dynamic runtime evaluation).
    #
    # @example Find a post by ID from the context
    #   find_by :post
    #
    # @example Find by query using context value
    #   find_by :post, query: { slug: :slug }, required: true
    #
    # @example Find using a dynamic lambda
    #   find_by :post, query: { created_at: -> { 1.week.ago..Time.current } }
    #
    # @example Find all posts for a user with a scope
    #   find_where :post, where: { user_id: :user_id }, scope: :published
    #
    # @see InteractorSupport::Actions
    module Findable
      extend ActiveSupport::Concern
      include InteractorSupport::Core

      included do
        class << self
          # Adds a `before` callback to find a single record and assign it to context.
          #
          # This method searches for a record based on the provided query parameters.
          # It supports dynamic values using symbols (context keys) and lambdas (for runtime evaluation).
          #
          # @param model [Symbol, String] the name of the model to query (e.g., `:post`)
          # @param query [Hash{Symbol=>Object,Proc}] a hash of attributes to match (can use symbols for context lookup or lambdas)
          # @param context_key [Symbol, nil] the key under which to store the result in context (defaults to the model name)
          # @param required [Boolean] if true, fails the context if no record is found
          #
          # @example Basic ID-based lookup
          #   find_by :post
          #
          # @example Query with context value
          #   find_by :post, query: { slug: :slug }
          #
          # @example Query with a lambda
          #   find_by :post, query: { created_at: -> { 1.week.ago..Time.current } }
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
                      when Symbol then context[v]
                      when Proc then instance_exec(&v)
                      else v
                      end
                    end,
                  )
                end

              context[context_key] = record
              context.fail!(errors: ["#{model} not found"]) if required && record.nil?
            end
          end

          # Adds a `before` callback to find multiple records and assign them to context.
          #
          # This method performs a `.where` query with optional `.where.not` and `.scope`,
          # allowing dynamic values using symbols (for context lookup) and lambdas (for runtime evaluation).
          #
          # @param model [Symbol, String] the name of the model to query (e.g., `:post`)
          # @param where [Hash{Symbol=>Object,Proc}] conditions for `.where` (can use symbols or lambdas)
          # @param where_not [Hash{Symbol=>Object,Proc}] conditions for `.where.not`
          # @param scope [Symbol, nil] optional named scope to call on the model
          # @param context_key [Symbol, nil] the key under which to store the result in context (defaults to pluralized model name)
          # @param required [Boolean] if true, fails the context if no records are found
          #
          # @example Where query with symbol context values
          #   find_where :post, where: { user_id: :user_id }
          #
          # @example Where with a lambda and scope
          #   find_where :post, where: { created_at: -> { 5.days.ago..Time.current } }, scope: :published
          #
          # @example Where with exclusions
          #   find_where :post, where: { user_id: :user_id }, where_not: { active: false }
          def find_where(model, where: {}, where_not: {}, scope: nil, context_key: nil, required: false)
            context_key ||= model.to_s.pluralize.to_sym
            before do
              query = model.to_s.classify.constantize

              query = query.where(
                where.transform_values do |v|
                  case v
                  when Symbol then context[v]
                  when Proc then instance_exec(&v)
                  else v
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
