# frozen_string_literal: true

module InteractorSupport
  module Concerns
    ##
    # The `Organizable` module provides utility methods for organizing interactors
    # and shaping request parameters in a structured way.
    #
    # It is intended to be included into a controller or a base service class that
    # delegates to interactors using request objects.
    #
    # @example Include in a controller
    #   class ApplicationController < ActionController::Base
    #     include InteractorSupport::Organizable
    #   end
    #
    # @see InteractorSupport::Organizable#organize
    # @see InteractorSupport::Organizable#request_params
    module Organizable
      include ActiveSupport::Concern

      # Calls the given interactor with a request object.
      # Optionally wraps the request object under a key in the interactor context.
      #
      # @param interactor [Class] The interactor class to call.
      # @param params [Hash] Parameters to initialize the request object.
      # @param request_object [Class] A request object class that responds to `#new(params)`.
      # @param context_key [Symbol, nil] Optional key to assign the request object under in the context.
      #
      # @return [void]
      #
      # @example
      #  organize(MyInteractor, params: request_params, request_object: MyRequest)
      #  # => Calls MyInteractor with an instance of MyRequest initialized with request_params.
      #
      # @example
      #   organize(MyInteractor, params: request_params, request_object: MyRequest, context_key: :request)
      #   # => Calls MyInteractor with an instance of MyRequest initialized with request_params at :context_key.
      #   #   # => The context will contain { request: MyRequest.new(request_params) }
      def organize(interactor, params:, request_object:, context_key: nil)
        @context = interactor.call(
          context_key ? { context_key => request_object.new(params) } : request_object.new(params),
        )
      end

      # Builds a structured and optionally transformed parameter hash from Rails' `params`.
      #
      # This method supports extracting specific top-level keys, applying optional rewrite
      # transformations, merging in additional values, and excluding unwanted keys.
      #
      # @param top_level_keys [Array<Symbol>] Top-level keys to extract from `params`. If empty, all keys are included.
      # @param merge [Hash] Additional values to merge into the final result.
      # @param except [Array<Symbol, Array<Symbol>>] Keys or nested key paths to exclude from the result.
      # @param rewrite [Array<Hash>] A set of transformation rules applied to the top-level keys.
      #
      # @return [Hash] The final, shaped parameters hash.
      #
      # @example Extracting a specific top-level key
      #   # Given: params = { order: { product_id: 1, quantity: 2 } }
      #   request_params(:order)
      #   # => { order: { product_id: 1, quantity: 2 } }
      #
      # @example Without top-level keys (includes all)
      #   # Given: params = { order: { product_id: 1 }, app_id: 123 }
      #   request_params()
      #   # => { order: { product_id: 1 }, app_id: 123 }
      #
      # @example Merging and excluding
      #   # Given: params = { order: { product_id: 1, quantity: 2 }, internal: "yes" }
      #   request_params(:order, merge: { user_id: 123 }, except: [[:order, :quantity], :internal])
      #   # => { order: { product_id: 1 }, user_id: 123 }
      #
      # @example Flattening a nested hash into the top-level
      #   # Given: params = { order: { product_id: 1, quantity: 2 }, app_id: 123 }
      #   request_params(:order, rewrite: [{ order: { flatten: true } }])
      #   # => { product_id: 1, quantity: 2 }
      #
      # @example Rename a top-level key and filter nested keys
      #   # Given: params = { metadata: { source: "mobile", internal: "x" } }
      #   request_params(:metadata, rewrite: [
      #     { metadata: { as: :meta, only: [:source] } }
      #   ])
      #   # => { meta: { source: "mobile" } }
      #
      # @example Provide a default value if a key is missing
      #   # Given: params = {}
      #   request_params(:session, rewrite: [
      #     { session: { default: { id: nil } } }
      #   ])
      #   # => { session: { id: nil } }
      #
      # @example Merge values into a nested structure
      #   # Given: params = { flags: { foo: true } }
      #   request_params(:flags, rewrite: [
      #     { flags: { merge: { debug: true } } }
      #   ])
      #   # => { flags: { foo: true, debug: true } }
      #
      # @example Combine multiple rewrite rules
      #   # Given:
      #   # params = {
      #   #   order: { product_id: 1, quantity: 2 },
      #   #   metadata: { source: "mobile", location: { ip: "1.2.3.4" } },
      #   #   tracking: { click_id: "abc", session_id: "def" }
      #   # }
      #   request_params(:order, :metadata, :tracking, rewrite: [
      #     { order: { flatten: true } },
      #     { metadata: { as: :meta, only: [:source, :location], flatten: [:location] } }
      #   ])
      #   # => {
      #   #   product_id: 1,
      #   #   quantity: 2,
      #   #   meta: { source: "mobile", ip: "1.2.3.4" },
      #   #   tracking: { click_id: "abc", session_id: "def" }
      #   # }
      def request_params(*top_level_keys, merge: {}, except: [], rewrite: [])
        permitted = params.permit!.to_h.deep_symbolize_keys
        data = top_level_keys.any? ? permitted.slice(*top_level_keys) : permitted

        apply_rewrites!(data, rewrite)

        data
          .deep_merge(merge)
          .then { |result| except.any? ? deep_except(result, except) : result }
      end

      private

      def apply_rewrites!(data, rewrites)
        rewrites.each do |rule|
          key, config = rule.first
          config = { flatten: true } if config == :flatten

          original = data.key?(key) ? data.delete(key) : nil
          transformed = original.deep_dup if original.is_a?(Hash)
          transformed ||= original

          # Filtering
          transformed.slice!(*config[:only]) if config[:only] && transformed.respond_to?(:slice!)
          transformed.except!(*config[:except]) if config[:except] && transformed.respond_to?(:except!)

          # Flatten specific nested keys
          if config[:flatten].is_a?(Array) && transformed.is_a?(Hash)
            config[:flatten].each do |subkey|
              nested = transformed.delete(subkey)
              if nested.is_a?(Hash)
                transformed.merge!(nested)
              elsif nested.is_a?(Array)
                raise ArgumentError,
                  "Cannot flatten array for the key `#{subkey}`. Flattening arrays of hashes is not supported."
              end
            end
          end

          # Apply default if nil or missing
          transformed ||= config[:default]

          # Merge additional keys
          if config[:merge]
            transformed = transformed.is_a?(Hash) ? transformed.merge(config[:merge]) : config[:merge]
          end

          # Fully flatten to top level
          if config[:flatten] == true && transformed.is_a?(Hash)
            data.merge!(transformed)
          else
            target_key = config[:as] || key
            data[target_key] = transformed
          end
        end
      end

      def deep_except(hash, paths)
        paths.reduce(hash) { |acc, path| remove_nested_key(acc, Array(path)) }
      end

      def remove_nested_key(hash, path)
        return hash unless path.is_a?(Array) && path.any?

        key, *rest = path
        return hash unless hash.key?(key)

        duped = hash.dup
        if rest.empty?
          duped.delete(key)
        elsif duped[key].is_a?(Hash)
          duped[key] = remove_nested_key(duped[key], rest)
        end

        duped
      end
    end
  end
end
