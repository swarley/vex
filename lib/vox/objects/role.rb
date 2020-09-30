# frozen_string_literal: true

require 'vox/objects/api_object'
require 'vox/objects/permissions'

module Vox
  # A permission object for a {User} in a {Guild}.
  class Role < APIObject
    # @!attribute [r] id
    #   @return [String]
    attr_reader :id

    # @!attribute [r] name
    #   @return [String]
    attr_reader :name

    # @!attribute [r] color
    #   @return [Integer]
    attr_reader :color

    # @!attribute [r] hoist
    #   @return [true, false]
    attr_reader :hoist
    alias hoist? hoist

    # @!attribute [r] position
    #   @return [Integer]
    attr_reader :position

    # @!attribute [r] permissions
    #   @return [Permissions]
    attr_reader :permissions

    # @!attribute [r] managed
    #   @return [true, false]
    attr_reader :managed
    alias managed? managed

    # @!attribute [r] mentionable
    #   @return [true, false]
    attr_reader :mentionable
    alias mentionable? mentionable

    def update_data(data)
      data[:permissions] = Permissions.new(data[:permissions].to_i) if data[:permissions]

      super
    end
  end
end
