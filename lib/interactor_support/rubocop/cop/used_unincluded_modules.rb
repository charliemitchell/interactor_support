# frozen_string_literal: true

require 'rubocop'
require_relative 'base_interactor_cop'

module RuboCop
  module Cop
    class UsedUnincludedModules < BaseInteractorCop
      MSG_MISSING_INTERACTOR = '`include Interactor` is required when including `%<module>s`.'
      MSG_MISSING_MODULE = 'Method `%<method>s` is used but `%<module>s` is not included.'

      private

      def check_interactor_usage(node)
        included_modules = extract_included_modules(node)
        used_methods = extract_used_methods_with_nodes(node)

        interactor_included = included_modules.any? { |_, mod| mod == 'Interactor' }

        included_modules.each do |include_node, mod|
          if mod.start_with?('InteractorSupport') && !interactor_included
            add_offense(include_node, message: format(MSG_MISSING_INTERACTOR, module: mod))
          end
        end

        return unless interactor_included

        used_methods.each do |method_name, method_node|
          missing_module = module_for_method_name(method_name)
          next if missing_module.nil? || included_modules.any? { |_, mod| mod == missing_module }

          # Register offense on the exact method call
          add_offense(
            method_node,
message: format(MSG_MISSING_MODULE, method: method_name, module: missing_module),
severity: :info,
          )
        end
      end

      def extract_used_methods_with_nodes(node)
        node.each_descendant(:send).map { |send_node| [send_node.method_name, send_node] }
      end
    end
  end
end
