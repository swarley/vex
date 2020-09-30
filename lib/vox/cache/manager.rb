# frozen_string_literal: true

# frozen_string_literal: true

require 'vox/cache/memory'

module Vox
  module Cache
    # Manages caches, index by symbol keys. Used by {Vox::Client}.
    class Manager
      attr_accessor :default

      # @yield [self]
      def initialize(default: Memory, **options)
        @caches = options
        @default = default
        yield(self) if block_given?
      end

      # Retrieve a key from a managed cache.
      # @param cache [Symbol]
      # @param key [String]
      def get(cache, key, &block)
        cache_or_default(cache)

        @caches[cache].get(key, &block)
      end

      # Set a key for a managed cache.
      # @param cache [Symbol]
      # @param key [String]
      # @param value [Object]
      # @return [Object] The value that was set
      def set(cache, key, value)
        cache_or_default(cache)

        @caches[cache].set(key, value)
      end

      # Retrieve a cache by name.
      # @param name [Symbol]
      # @return [Cache::Base]
      def [](name)
        @caches[name] ||= cache_or_default(name)
      end

      # Remove a key from a managed cache.
      # @param cache [Symbol]
      # @param key [String]
      # @return [nil]
      def delete(cache, key)
        cache_or_default(cache)

        @caches[cache].delete(key)
      end

      private

      # Returns a cache if it exists, or create a new one from a the given
      # default.
      # @param cache [Symbol]
      def cache_or_default(cache)
        @caches[cache] ||= if @default_cache.respond_to?(:call)
                             @default.call
                           else
                             @default.new
                           end
      end
    end
  end
end
