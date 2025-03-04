# frozen_string_literal: true

module RuboCop
  module Cop
    class RequireRequiredForInteractorSupport < Cop
      MSG = 'Classes including `InteractorSupport` or `InteractorSupport::Validations` must invoke `required`.'

      def_node_matcher :calls_required?, <<~PATTERN
        (send nil? :required ...)
      PATTERN

      def includes_support?(node)
        node.to_s =~ /\(const nil :InteractorSupport\) :Validations\)/ ||
          node.to_s =~ /\(const nil :InteractorSupport\)/
      end

      def on_class(node)
        return unless includes_support?(node)

        required_called = calls_required?(node.body) || node.body&.children&.any? do |child|
          calls_required?(child)
        end
        add_offense(node, message: MSG) unless required_called
      end

      # def on_send(node)
      #   if includes_interactor_support?(node)
      #     puts "Matched node: #{node}"
      #   else
      #     puts "Node did not match: #{node}"
      #   end
      # end

      # def on_send(node)
      #   puts node
      #   return nil unless node.method_name == :include

      #   byebug
      #   # if node.arguments.any? { |arg| arg.const_name == :InteractorSupport }
      #   #   add_offense(node, message: MSG)
      #   # elsif node.arguments.any? { |arg| arg.const_name == :Validations }
      #   #   add_offense(node, message: MSG)
      #   # end
      # end
    end
  end
end
