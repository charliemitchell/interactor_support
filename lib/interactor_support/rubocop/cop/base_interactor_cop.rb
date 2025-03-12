# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    class BaseInteractorCop < RuboCop::Cop::Base
      def on_class(node)
        check_interactor_usage(node)
      end

      def on_module(node)
        check_interactor_usage(node)
      end

      private

      def extract_included_modules(node)
        node.each_descendant(:send)
          .select { |send_node| send_node.method?(:include) }
          .map { |send_node| [send_node, send_node.first_argument&.const_name] }
          .reject { |_, name| name.nil? }
      end

      def extract_used_methods(node)
        node.each_descendant(:send).map(&:method_name)
      end

      def known_module_methods
        {
          'InteractorSupport::Concerns::Findable' => [:find_by, :find_where],
          'InteractorSupport::Concerns::Skippable' => [:skip],
          'InteractorSupport::Concerns::Transactionable' => [:transaction],
          'InteractorSupport::Concerns::Transformable' => [:context_variable, :transform],
          'InteractorSupport::Concerns::Updatable' => [:update],
          'InteractorSupport::Validations' => validations_methods,
        }
      end

      def module_for_method_name(method_name)
        known_module_methods.each do |mod, methods|
          return mod if methods.include?(method_name)
        end
        nil
      end

      def validations_methods
        [
          :required,
          :optional,
          :context_accessor,
          :validates_after,
          :validates_before,
          :after_validation,
          :before_validation,
          :validates_acceptance_of,
          :validates_numericality_of,
          :validates_presence_of,
          :validates_length_of,
          :validates_size_of,
          :validates_comparison_of,
          :validates_confirmation_of,
          :validates_absence_of,
          :validates_exclusion_of,
          :validates_format_of,
          :validates_inclusion_of,
          :human_attribute_name,
          :lookup_ancestors,
          :i18n_scope,
          :descendants,
          :reset_callbacks,
          :define_callbacks,
          :set_callback,
          :normalize_callback_params,
          :get_callbacks,
          :set_callbacks,
          :skip_callback,
          :define_model_callbacks,
          :model_name,
          :clear_validators!,
          :validators_on,
          :attribute_method?,
          :validates,
          :validates!,
          :validates_each,
          :validates_with,
          :validate,
          :validators,
          :yaml_tag,
        ]
      end
    end
  end
end
