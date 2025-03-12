# frozen_string_literal: true

module RuboCop
  module Cop
    class RequireRequiredForInteractorSupport < Cop
      MSG = 'Classes including `InteractorSupport` or `InteractorSupport::Validations` must invoke `required`.'

      def_node_matcher :calls_required?, <<~PATTERN
        (send nil? :required ...)
      PATTERN

      def includes_support?(node)
        node.to_s =~ /InteractorSupport/ && (
          node.to_s =~ /\(const nil :InteractorSupport\) :Validations\)/ ||
          (node.to_s =~ /\(const nil :InteractorSupport\)/ && node.to_s !~ /:RequestObject/)
        )
      end

      def on_class(node)
        return unless includes_support?(node)

        required_called = calls_required?(node.body) || node.body&.children&.any? do |child|
          calls_required?(child)
        end
        add_offense(node, message: MSG) unless required_called
      end
    end
  end
end
