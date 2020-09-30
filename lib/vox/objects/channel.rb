# frozen_string_literal: true

require 'time'
require 'vox/objects/api_object'
require 'vox/objects/permissions'

module Vox
  # A channel object with HTTP methods.
  class Channel < APIObject
    # Overwrite object for channel permissions.
    class Overwrite
      # Allowed permissions bit set.
      # @return [Permissions]
      attr_reader :allow

      # Denied permissions bit set.
      # @return [Permissions]
      attr_reader :deny

      # Role or User ID.
      # @return [String]
      attr_reader :id

      # The type this override corresponds to.
      # @return ["role", "member"]
      attr_reader :type

      # @param data [Hash]
      # @option data [String] allow Allowed permissions bit set.
      # @option data [String] deny Denied permissions bit set.
      # @option data [String] id Role or User ID.
      # @option data ["role", "member"] type The type this override corresponds to.
      def initialize(**data)
        @allow = Permissions.new(data[:allow])
        @deny = Permissions.new(data[:deny])
        @id = data[:id].to_s
        @type = data[:type]
      end
    end

    # @!visibility private
    TYPES = {
      text: 0,
      dm: 1,
      voice: 2,
      group_dm: 3,
      category: 4,
      news: 5,
      store: 6
    }.freeze

    # @!group Type Checking

    # @!method text?
    #   @return [true, false]
    # @!method dm?
    #   @return [true, false]
    # @!method voice?
    #   @return [true, false]
    # @!method group_dm?
    #   @return [true, false]
    # @!method category?
    #   @return [true, false]
    # @!method news?
    #   @return [true, false]
    # @!method store?
    #   @return [true, false]

    TYPES.each do |name, value|
      define_method("#{name}?") { @type == value }
    end
    # @!endgroup

    # @return [String]
    attr_reader :id

    # @return [String]
    attr_reader :guild_id

    # @return [String]
    attr_reader :last_message_id

    # @return [Array<User>]
    attr_reader :recipients

    # @return [String]
    attr_reader :icon

    # @return [String]
    attr_reader :owner_id

    # @return [String]
    attr_reader :application_id

    # @return [Time]
    attr_reader :last_pin_timestamp

    # @!group Modifiable Attributes

    # @!attribute [rw] name
    # @return [String]
    modifiable :name

    # @!attribute [rw] type
    # @return [Integer]
    modifiable :type

    # @!attribute [rw] position
    # @return [Integer]
    modifiable :position

    # @!attribute [rw] topic
    # @return [String]
    modifiable :topic

    # @!attribute [rw] nsfw
    # @return [true, false]
    modifiable :nsfw
    alias nsfw? nsfw

    # @!attribute [rw] rate_limit_per_user
    # @return [Integer]
    modifiable :rate_limit_per_user

    # @!attribute [rw] bitrate
    # @return [Integer]
    modifiable :bitrate

    # @!attribute [rw] user_limit
    # @return [Integer]
    modifiable :user_limit

    # @!attribute [rw] permission_overwrites
    # @return [Array<Overwrite>]
    modifiable :permission_overwrites

    # @!attribute [rw] parent_id
    # @return [String, Integer]
    modifiable :parent_id

    # @!endgroup

    # @param [Hash] attrs the attributes to modify on the channel.
    # @option attrs [String] name
    # @option attrs [Integer] type Only conversion between text and news is supported.
    # @option attrs [Integer] position
    # @option attrs [String] topic
    # @option attrs [true, false] nsfw
    # @option attrs [Integer] rate_limit_per_user
    # @option attrs [Integer] bitrate
    # @option attrs [Integer] user_limit
    # @option attrs [Overwrite, Hash] permission_overwrites
    # @option attrs [String, Integer] parent_id
    # @see Vox::HTTP::Routes::Channel#modify_channel Modify channel options
    def modify(**attrs)
      @client.http.modify_channel(@id, **attrs)
    end

    # @!attribute [r] guild
    # @return [Guild, nil] The guild that owns this channel.
    def guild
      @guild_id ? @client.guild(@guild_id) : nil
    end

    # @!attribute [r] parent
    # @return [Channel, nil] The parent category channel.
    def parent
      @parent_id ? @client.channel(@parent_id) : nil
    end

    # @!visibility private
    # @param data [Hash] The data to update the object with.
    def update_data(data)
      data.delete(:guild_hashes)

      if data.include?(:recipients)
        data[:recipients].map! do |user_data|
          User.new(@client, user_data) unless user_data.is_a?(User)
        end

        data[:recipients].each { |u| @client.cache_upsert(:user, u[:id], u) }
      end

      if data.include?(:last_pin_timestamp) && data[:last_pin_timestamp].is_a?(String)
        lpt = data[:last_pin_timestamp]
        data[:last_pin_timestamp] = lpt ? Time.iso8601(lpt) : nil
      end

      super
    end
  end
end
