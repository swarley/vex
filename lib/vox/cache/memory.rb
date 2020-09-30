# frozen_string_literal: true

require 'vox/cache/base'

module Vox
  module Cache
    # A cache that uses a hash as the storage method.
    class Memory < Base
      def initialize
        @data = {}
        super
      end

      # Retrieve a value from the cache by key
      # @param key [String] This will typically be an ID.
      # @return [Object]
      def get(key)
        @data[key]
      end

      # Set a value in the cache
      # @param key [String]
      # @param value [Object]
      # @return [Object] The provided value.
      def set(key, value)
        @data[key] = value
      end

      # Delete a value from the cache
      # @param key [String]
      # @return [nil]
      def delete(key)
        @data.delete(key)
      end
    end
  end
end
