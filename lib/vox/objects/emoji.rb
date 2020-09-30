# frozen_string_literal: true

require 'vox/objects/api_object'

module Vox
  # Custom emojis object.
  class Emoji < APIObject
    # @!attribute [r] id
    #   @return [String]
    attr_reader :id

    # @!attribute [r] name
    #   @return [String]
    attr_reader :name

    # @!attribute [r] roles
    #   @return [Array<Role>, nil]
    attr_reader :roles

    # @!attribute [r] user
    #   @return [User, nil]
    attr_reader :user

    # @!attribute [r] require_colons
    #   @return [true, false, nil]
    attr_reader :require_colons
    alias require_colons? require_colons

    # @!attribute [r] managed
    #   @return [true, false, nil]
    attr_reader :managed
    alias managed? managed

    # @!attribute [r] animated
    #   @return [true, false, nil]
    attr_reader :animated
    alias animated? animated

    # @!attribute [r] available
    #   @return [true, false, nil]
    attr_reader :available
    alias available? available

    # @!group Modifiable Attributes

    # Set roles that are whitelisted to use this emoji.
    modifiable :roles

    # The name of this emoji.
    modifiable :name

    # @!endgroup

    # Modify attributes of this emoji.
    # @param name [String]
    # @param roles [Array<Role, String, Integer>] A list of roles or IDs to restrict usage to.
    def modify(name: :undef, roles: :undef)
      roles = roles.is_a?(Array) ? roles.collect { |obj| obj&.id || obj } : roles

      @client.modify_guild_emoji(guild.id, @id, name: name, role: roles)
    end

    # @return [Guild, nil] The guild that owns this emoji.
    # @note Emoji's are not guaranteed to have an associated Guild available.
    def guild
      raise Vox::Error.new('No associated guild') unless @guild_id

      @client.guild(@guild_id)
    end

    # @!visibility private
    def update_data(data)
      data[:user] = User.new(@client, data[:user]) if data[:user]
      data[:id] = data[:id].to_s if data[:id]

      super
    end
  end
end
