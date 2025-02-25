module InteractorSupport
  module Concerns
    module Transformable
      extend ActiveSupport::Concern

      included do
        class << self
          # context_variable first_post: Post.first
          # context_variable user: -> { User.find(user_id) }
          # context_variable items: Item.all
          # context_variable numbers: [1, 2, 3]
          def context_variable(key_values)
            before do
              key_values.each do |key, value|
                if value.is_a?(Proc)
                  context[key] = context.instance_exec(&value)
                else
                  context[key] = value
                end
              end
            end
          end

          # transform :email, :name, with: [:downcase, :strip]
          # transform :url, with: :downcase
          # transform :items, with: :compact
          # transform :items, with: ->(value) { value.compact }
          # transform :email, :url, with: ->(value) { value.downcase.strip }
          # transform :items, with: :compact
          def transform(*keys, with: [])
            before do
              if keys.empty?
                raise ArgumentError, "transform action requires at least one key."
              end

              keys.each do |key|
                if with.is_a?(Proc)
                  begin
                    context[key] = context.instance_exec(&with)
                  rescue => e
                    context.fail!(errors: ["#{key} failed to transform: #{e.message}"])
                  end
                elsif with.is_a?(Array)
                  context.fail!(errors: ["#{key} does not respond to all transforms"]) unless with.all? { |t| t.is_a?(Symbol) && context[key].respond_to?(t) }
                  context[key] = with.inject(context[key]) do |value, method|
                    value.send(method)
                  end
                elsif with.is_a?(Symbol) && context[key].respond_to?(with)
                  context[key] = context[key].send(with)
                elsif with.is_a?(Symbol)
                  context.fail!(errors: ["#{key} does not respond to #{with}"])
                else
                  raise ArgumentError, "transform requires `with` to be a symbol or array of symbols."
                end
              end
            end
          end
        end
      end
    end
  end
end