# frozen_string_literal: true

require 'vox/objects/api_object'

module Vox
  # Users in Discord are generally considered the base entity. Users can spawn across the entire platform,
  # be members of guilds, participate in text and voice chat, and much more. Users are separated by a distinction of
  # "bot" vs "normal." Although they are similar, bot users are automated users that are "owned" by another user.
  # Unlike normal users, bot users do not have a limitation on the number of Guilds they can be a part of.
  class User < APIObject
    # Flags that give information about badges on a
    # user.
    FLAGS = {
      discord_employee: 1 << 0,
      discord_partner: 1 << 1,
      hypesquad_events: 1 << 2,
      bug_hunter_level_1: 1 << 3,
      house_bravery: 1 << 6,
      house_brilliance: 1 << 7,
      house_balance: 1 << 8,
      early_supporter: 1 << 9,
      team_user: 1 << 10,
      system: 1 << 12,
      bug_hunter_level_2: 1 << 14,
      verified_bot: 1 << 16,
      verified_bot_developer: 1 << 17
    }.freeze

    # @!attribute [r]
    # @return [String]
    attr_reader :id

    # @!attribute [r]
    # @return [String]
    attr_reader :username

    # @!attribute [r]
    # @return [String]
    attr_reader :discriminator

    # @!attribute [r]
    # @return [String, nil]
    attr_reader :avatar

    # @!attribute [r]
    # @return [true, false, nil]
    attr_reader :bot

    # @!attribute [r]
    # @return [true, false, nil]
    attr_reader :system

    # @!attribute [r]
    # @return [true, false, nil]
    attr_reader :mfa_enabled

    # @!attribute [r]
    # @return [String, nil]
    attr_reader :locale

    # @!attribute [r]
    # @return [true, false, nil]
    attr_reader :verified

    # @!attribute [r]
    # @return [String, nil]
    attr_reader :email

    # @!attribute [r]
    # @return [Integer, nil]
    attr_reader :flags

    # @!attribute [r]
    # @return [Integer, nil]
    attr_reader :premium_type

    # @!attribute [r]
    # @return [Integer, nil]
    attr_reader :public_flags

    # @return [true, false]
    def nitro?
      @premium_type&.positive?
    end

    # @return [:none, :classic, :nitro]
    def nitro_type
      %i[none classic nitro][@premium_type]
    end

    # @!group Flags

    # @!method discord_employee?
    #   @return [true, false]
    # @!method discord_partner?
    #   @return [true, false]
    # @!method hypesquad_events?
    #   @return [true, false]
    # @!method bug_hunter_level_1?
    #   @return [true, false]
    # @!method house_bravery?
    #   @return [true, false]
    # @!method house_brilliance?
    #   @return [true, false]
    # @!method house_balance?
    #   @return [true, false]
    # @!method early_supporter?
    #   @return [true, false]
    # @!method team_user?
    #   @return [true, false]
    # @!method system?
    #   @return [true, false]
    # @!method bug_hunter_level_2?
    #   @return [true, false]
    # @!method verified_bot?
    #   @return [true, false]
    # @!method verified_bot_developer?
    #   @return [true, false]
    flags :@public_flags, **FLAGS

    # @endgroup
  end

  # A Profile is a special type of user object that refers to a OAuth2 user,
  # or the current bot application.
  class Profile < User
    # @return [String]
    attr_reader :token

    # Retrieve a list of DM channels for a user.
    # @return [Array<Channel>]
    def dms
      @client.http.get_user_dms.colect do |data|
        @client.cache_upsert(:channel, data[:id].to_s, Channel.new(@client, data))
      end
    end

    # Create a new DM channel with for a target user.
    # @param recipient_id [String, Integer] The target user ID.
    # @return [Channel]
    def create_dm(recipient_id)
      data = @client.http.create_dm(recipient_id)
      @client.cache_upsert(:channel, data[:id], Channel.new(@client, data))
    end

    # Leave a guild.
    # @param guild_id [String, Integer] The ID of the guild to leave.
    def leave_guild(guild_id)
      @client.http.leave_guild(guild_id)
    end

    # The connections of the user.
    # @return [Array<Connection>]
    def connections
      @client.http.get_user_connections
    end

    # @!group Modifiable Attributes

    # @return [String]
    modifiable :username

    # @return [String, nil]
    modifiable :avatar

    # @!endgroup

    def modify(username: nil, avatar: nil)
      @client.http.modify_current_user(username: username, avatar: avatar)
    end

    # A connection a user has to a service.
    class Connection < APIObject
      # @!attribute [r] id
      #   @return [String]
      attr_reader :id

      # @!attribute [r] name
      #   @return [String]
      attr_reader :name

      # @!attribute [r] type
      #   @return [String]
      attr_reader :type

      # @!attribute [r] revoked
      #   @return [true, false, nil]
      attr_reader :revoked
      alias revoked? revoked

      # @!attribute [r] integrations
      #   @return [Array<Guild::Integration>, nil]
      attr_reader :integrations

      # @!attribute [r] verified
      #   @return [true, false]
      attr_reader :verified
      alias verified? verified

      # @!attribute [r] friend_sync
      #   @return [true, false]
      attr_reader :friend_sync
      alias friend_sync? friend_sync

      # @!attribute [r] show_activity
      #   @return [true, false]
      attr_reader :show_activity
      alias show_activity? show_activity

      # @!attribute [r] visibility
      #   @return [true, false]
      attr_reader :visibility
      alias visible? visibility

      # @!visibility private
      def update_data(data)
        inte = data[:integrations]
        data[:integrations] = inte.collect { |d| Guild::Integration.new(@client, d) } if inte

        super
      end
    end
  end
end
