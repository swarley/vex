# frozen_string_literal: true

module Vox
  # Module that contains tools for managing a cache.
  module Cache
    # Noop cache that only provides interface methods
    class Base
      # Retrieve a value from the cache by key
      # @param _key [String] This will typically be an ID.
      # @return [nil]
      def get(_key); end

      # Set a value in the cache
      # @param _key [String]
      # @param value [Object]
      # @return [Object] The provided value.
      def set(_key, value)
        value
      end

      # Delete a value from the cache
      # @param _key [String]
      # @return [nil]
      def delete(_key); end
    end
  end
end
