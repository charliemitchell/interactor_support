# frozen_string_literal: true

require 'rubocop'
require_relative 'base_interactor_cop'

module RuboCop
  module Cop
    class UnusedIncludedModules < BaseInteractorCop
      MSG_SINGLE = 'Module `%<module>s` is included but its methods are not used in this class.'
      MSG_GROUP = 'Use `%<correct_modules>s` instead.'

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

      private

      def check_interactor_usage(node)
        included_modules = extract_included_modules(node)
        used_methods = extract_used_methods(node)

        included_modules.each do |include_node, mod|
          next unless mod.start_with?('InteractorSupport')
          next if mod == 'InteractorSupport::RequestObject'

          expanded_modules = GROUP_MODULES.fetch(mod, [mod])
          unused_modules = expanded_modules.reject do |m|
            known_module_methods[m]&.any? { |meth| used_methods.include?(meth) }
          end

          next if unused_modules.empty?

          missing_modules = []
          used_methods.each do |method_name|
            missing_module = module_for_method_name(method_name)
            next if missing_module.nil? || included_modules.any? { |_, mod| mod == missing_module }

            missing_modules << missing_module unless missing_modules.include?(missing_module)
          end

          modules = missing_modules.map { |missing_module| "include #{missing_module}" }
          message = if unused_modules.size == 1
            format(MSG_SINGLE, module: unused_modules.first)
          else
            format(MSG_GROUP, correct_modules: modules.join(', '))
          end

          add_offense(include_node, message: message)
        end
      end
    end
  end
end
