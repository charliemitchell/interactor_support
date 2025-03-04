module InteractorSupport
  module Concerns
    module Skippable
      extend ActiveSupport::Concern

      included do
        class << self
          def skip(**options)
            around do |interactor|
              unless options[:if].nil?
                condition = if options[:if].is_a?(Proc)
                  context.instance_exec(&options[:if])
                elsif options[:if].is_a?(Symbol) && respond_to?(options[:if])
                  send(options[:if])
                elsif options[:if].is_a?(Symbol)
                  context[options[:if]]
                else
                  options[:if]
                end

                next if condition
              end

              unless options[:unless].nil?
                condition = if options[:unless].is_a?(Proc)
                  context.instance_exec(&options[:unless])
                elsif options[:unless].is_a?(Symbol) && respond_to?(options[:unless])
                  send(options[:unless])
                elsif options[:unless].is_a?(Symbol)
                  context[options[:unless]]
                else
                  options[:unless]
                end

                next unless condition
              end

              interactor.call
            end
          end
        end
      end
    end
  end
end
