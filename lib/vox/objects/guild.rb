# frozen_string_literal: true

require 'vox/objects/api_object'

module Vox
  # Guilds in Discord represent an isolated collection of users and channels,
  # and are often referred to as "servers" in the UI.
  class Guild < APIObject
    # @!group Modifiable Attributes

    # @!attribute [rw] name
    # @return [String]
    modifiable :name

    # @!attribute [rw] region
    # @return [String]
    modifiable :region

    # @!attribute [rw] verification_level
    # @return [Integer]
    modifiable :verification_level

    # @!attribute [rw] default_message_notifications
    # @return [Integer]
    modifiable :default_message_notifications

    # @!attribute [rw] explicit_content_filter
    # @return [Integer]
    modifiable :explicit_content_filter

    # @!attribute [rw] afk_channel_id
    # @return [String]
    modifiable :afk_channel_id

    # @!attribute [rw] afk_timeout
    # @return [Integer]
    modifiable :afk_timeout

    # @!attribute [rw] icon
    # @return [String]
    modifiable :icon

    # @!attribute [rw] owner_id
    # @return [String]
    modifiable :owner_id

    # @!attribute [rw] splash
    # @return [String]
    modifiable :splash

    # @!attribute [rw] banner
    # @return [String]
    modifiable :banner

    # @!attribute [rw] system_channel_id
    # @return [String]
    modifiable :system_channel_id

    # @!attribute [rw] rules_channel_id
    # @return [String]
    modifiable :rules_channel_id

    # @!attribute [rw] public_updates_channel_id
    # @return [String]
    modifiable :public_updates_channel_id

    # @!attribute [rw] preferred_locale
    # @return [String]
    modifiable :preferred_locale

    # @!endgroup

    def roles(cached: true)
      return @roles if @roles && cached

      update_data({ roles: @client.http.get_guild_roles(@id) })
    end

    def role(id)
      roles.find { |r| r.id == id }
    end

    def emojis(cached: true)
      return @emojis if @emojis && cached

      update_data({ emojis: @client.http.get_guild_emojis(@id) })
    end

    def emoji(id)
      emojis.find { |e| e.id == id }
    end

    def audit_log(user_id: :undef, action_type: :undef, before: :undef, limit: :undef)
      log = @client.http.get_guild_audit_log(@id, user_id: user_id, action_type: action_type,
                                                  before: before, limit: limit)
      AuditLog.new(@client, log)
    end

    def modify(**args)
      @client.http.modify_guild(@id, **args)
    end

    # @!visibility private
    def update_data(data)
      id_keys = %i[afk_channel_id owner_id system_channel_id rules_channel_id public_updates_channel_id]
      data.slice(id_keys).transform_values(&:to_s)

      data[:roles] = data[:roles].collect { |role_data| Role.new(@client, role_data) }
      data[:roles].each { |role| @client.cache_upsert(:role, role.id, role) }

      data[:emojis] = data[:emojis].collect { |emoji_data| Emoji.new(@client, emoji_data) }
      data[:emojis].each { |emoji| @client.cache_upsert(:emoji, emoji.id, emoji) }

      super
    end

    # Information about an integration with an external service.
    class Integration < APIObject
      # @!visibility private
      EXPIRE_BEHAVIOR = {
        remove_role: 0,
        kick: 1
      }.freeze

      # Integration account information.
      class Account < APIObject
        # @!attribute [r] id
        #   @return [String]
        attr_reader :id

        # @!attribute [r] name
        #   @return [String]
        attr_reader :name

        # @!visibility private
        def update_data(data)
          data[:id] = data[:id].to_s
          super
        end
      end

      # @!attribute [r] id
      #   @return [String]
      attr_reader :id

      # @!attribute [r] name
      #   @return [String]
      attr_reader :name

      # @!attribute [r] type
      #   @return [String]
      attr_reader :type

      # @!attribute [r] enabled
      #   @return [true, false]
      attr_reader :enabled
      alias enabled? enabled

      # @!attribute [r] syncing
      #   @return [true, false]
      attr_reader :syncing
      alias syncing? syncing

      # @!attribute [r] role_id
      #   @return [String]
      attr_reader :role_id

      # @!attribute [r] enabled_emoticons
      #   @return [true, false, nil]
      attr_reader :enabled_emoticons
      alias enabled_emoticons? enabled_emoticons

      # @!attribute [r] expire_behavior
      #   @return [Integer]
      attr_reader :expire_behavior

      # @!attribute [r] expire_grace_period
      #   @return [Integer]
      attr_reader :expire_grace_period

      # @!attribute [r] user
      #   @return [User]
      attr_reader :user

      # @!attribute [r] synced_at
      #   @return [Time]
      attr_reader :synced_at

      # @return [true, false]
      def kick_on_expire?
        @expire_behavior == EXPIRE_BEHAVIOR[:kick]
      end

      # @return [true, false]
      def remove_role_on_expire?
        @expire_behavior == EXPIRE_BEHAVIOR[:remove_role]
      end

      # @!visibility private
      def update_data(data)
        data[:user] = @client.cache_upsert(:user, data[:user][:id], data[:user])
        data[:account] = Account.new(data[:account])
        data[:synced_at] = Time.iso8601(data[:synced_at])
        super
      end
    end
  end

  # A user within the context of a {Guild}.
  class Member < APIObject
    # @!attribute [r] user
    #   @return [User, nil]
    attr_reader :user

    # @!attribute [r] nick
    #   @return [String]
    attr_reader :nick

    # @!attribute [r] roles
    #   @return [Array<Role>]
    attr_reader :roles

    # @!attribute [r] joined_at
    #   @return [Time]
    attr_reader :joined_at

    # @!attribute [r] premium_since
    #   @return [Time, nil]
    attr_reader :premium_since

    # @!attribute [r] deaf
    #   @return [true, false]
    attr_reader :deaf
    alias deaf? deaf

    # @!attribute [r] mute
    #   @return [true, false]
    attr_reader :mute
    alias mute? mute

    def initialize(client, data, guild)
      @guild = guild
      super(client, data)
    end

    # @!visibility private
    def update_data(data)
      data[:user] = User.new(@client, data[:user]) if data[:user]
      data[:joined_at] = Time.iso8601(data[:joined_at]) if data[:joined_at]
      data[:premium_since] = Time.iso8601(data[:premium_since]) if data[:premium_since]
      data[:roles] = @guild.roles.select { |r| data[:roles].include? r.id }

      super
    end
  end
end
