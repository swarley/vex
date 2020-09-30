# frozen_string_literal: true

module Vox
  # Base object for objects from the API that reference
  # a client and the response data.
  #
  # All returned fields are made available as reader methods.
  class APIObject
    def initialize(client, data)
      @client = client
      @mutex = Mutex.new
      update_data(data)
    end

    def difference(data)
      data.reject { |key, val| instance_variable_get("@#{key}") == val }
    end

    # Generic update_data for objects without nesting
    # @api private
    def update_data(data)
      @mutex.synchronize do
        keys = data.keys

        keys.each { |key| instance_variable_set("@#{key}", data[key]) }
      end
    end

    # Override the default inspect to not show internal instance variables.
    # @!visibility private
    def inspect
      relevant_ivars = instance_variables - %i[@client @__events @mutex]
      ivar_pairs = relevant_ivars.collect { |ivar| [ivar, instance_variable_get(ivar)] }
      ivar_strings = ivar_pairs.collect { |name, value| "#{name}=#{value.inspect}" }
      "#<#{self.class} #{ivar_strings.join(' ')}>"
    end

    # Compare other objects that respond to `#id` or suitible ID types,
    #  `String` and `Numeric`.
    def ==(other)
      if other.respond_to?(:id) && other.is_a?(self.class)
        @id.to_s == other.id.to_s
      elsif other.is_a?(Numeric) || other.is_a?(String)
        @id.to_s == other.to_s
      else
        false
      end
    end

    # Explicit conversion of API object to hash.
    # @!visibility private
    def to_hash
      (instance_variables - [@client, @mutex]).collect do |ivar|
        [ivar[1..-1].to_sym, instance_variable_get(ivar)]
      end.to_h
    end

    # Declares a reader, as well as an http based writer.
    def self.modifiable(key)
      attr_reader key

      define_method("#{key}=") { |data| modify(key => data) }
    end

    # Declares a set of bit flag keys, creating `?` methods for checking if
    # the flag is set.
    # @example
    #   class User < APIObject
    #     flags :@public_flags, discord_employee: 1 << 3
    #   end
    #
    #   User.new(client, { flags: 0b111111111 }).discord_employee?
    #   # => true
    def self.flags(var, **flags)
      flags.each do |flag, value|
        define_method("#{flag}?") { (instance_variable_get(var) & value).positive? }
      end
    end
  end
end
