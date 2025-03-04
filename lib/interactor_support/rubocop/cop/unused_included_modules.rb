# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    class UnusedIncludedModules < RuboCop::Cop::Base
      MSG_SINGLE = 'Module `%<module>s` is included but its methods are not used in this class.'
      MSG_GROUP = 'Use `%<correct_modules>s` instead'

      GROUP_MODULES = {
        'InteractorSupport' => [
          'InteractorSupport::Concerns::Findable',
          'InteractorSupport::Concerns::Skippable',
          'InteractorSupport::Concerns::Transactionable',
          'InteractorSupport::Concerns::Transformable',
          'InteractorSupport::Concerns::Updatable',
          'InteractorSupport::Validations',
        ],
        'InteractorSupport::Actions' => [
          'InteractorSupport::Concerns::Skippable',
          'InteractorSupport::Concerns::Transactionable',
          'InteractorSupport::Concerns::Updatable',
          'InteractorSupport::Concerns::Findable',
          'InteractorSupport::Concerns::Transformable',
        ],
      }.freeze

      def on_class(node)
        check_unused_modules(node)
      end

      def on_module(node)
        check_unused_modules(node)
      end

      private

      def check_unused_modules(node)
        included_modules = extract_included_modules(node)
        used_methods = extract_used_methods(node)

        included_modules.each do |include_node, mod|
          expanded_modules = GROUP_MODULES.fetch(mod, [mod])
          unused_modules = expanded_modules.reject do |m|
            known_module_methods(m).any? do |meth|
              used_methods.include?(meth)
            end
          end

          next if unused_modules.empty?

          missing_modules = []
          used_methods.each do |method_name|
            missing_module = module_for_method_name(method_name)
            module_already_included = included_modules.any? { |_, mod| mod == missing_module }
            next if module_already_included

            missing_modules << missing_module if missing_module && !missing_modules.include?(missing_module)
          end

          modules = missing_modules.map do |missing_module|
            "include #{missing_module}"
          end
          message = if unused_modules.size == 1
            format(MSG_SINGLE, module: unused_modules.first)
          else
            format(
              MSG_GROUP,
              module: mod,
              unused_modules: unused_modules.join(', '),
              correct_modules: modules.join(', '),
            )
          end
          add_offense(include_node, message: message)
        end
      end

      def extract_included_modules(node)
        node.each_descendant(:send)
          .select { |send_node| send_node.method?(:include) }
          .map { |send_node| [send_node, send_node.first_argument.const_name] }
          .reject { |_, name| name.nil? }
      end

      def extract_used_methods(node)
        node.each_descendant(:send).map(&:method_name)
      end

      def validations_methods
        Class.new do
          include InteractorSupport::Validations
        end.singleton_methods
      end

      def known_module_methods(module_name)
        case module_name
        when 'InteractorSupport::Concerns::Findable'
          [:find_by, :find_where]
        when 'InteractorSupport::Concerns::Skippable'
          [:skip]
        when 'InteractorSupport::Concerns::Transactionable'
          [:transaction]
        when 'InteractorSupport::Concerns::Transformable'
          [:context_variable, :transform]
        when 'InteractorSupport::Concerns::Updatable'
          [:update]
        when 'InteractorSupport::Validations'
          validations_methods
        else
          []
        end
      end

      def module_for_method_name(method_name)
        base = {
          find_by: 'InteractorSupport::Concerns::Findable',
          find_where: 'InteractorSupport::Concerns::Findable',
          skip: 'InteractorSupport::Concerns::Skippable',
          transaction: 'InteractorSupport::Concerns::Transactionable',
          context_variable: 'InteractorSupport::Concerns::Transformable',
          transform: 'InteractorSupport::Concerns::Transformable',
          update: 'InteractorSupport::Concerns::Updatable',
        }
        validations_methods.each do |method|
          base[method] = 'InteractorSupport::Validations'
        end
        base[method_name]
      end
    end
  end
end
