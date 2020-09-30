# frozen_string_literal: true

require 'vox/http/client'
require 'vox/gateway/client'
require 'vox/cache'
require 'vox/objects'

module Vox
  # A client that bridges the gateway, http, and stateful object components.
  class Client
    include EventEmitter

    attr_reader :http, :gateway

    def initialize(token:, cache_manager: Cache::Manager.new, gateway_options: {}, http_options: {})
      @cache_manager = cache_manager
      @http = HTTP::Client.new(**{ token: token }.merge(http_options))
      @gateway = create_gateway(token: token, options: gateway_options)

      setup_gateway_caching
    end

    # Retrieve an object from the cache or set it with a provided block.
    def cache(cache_key, key, cached: true)
      if cached
        @cache_manager.get(cache_key, key) || @cache_manager.set(cache_key, key, yield)
      else
        @cache_manager.set(cache_key, key, yield)
      end
    end

    # @!visibility private
    def cache_upsert(cache_key, key, data)
      obj = @cache_manager.get(cache_key, key)
      if obj
        obj.update_data(data.to_hash)
      else
        @cache_manager.set(cache_key, key, data)
        nil
      end
    end

    # @return [User]
    def user(id, cached: true)
      cache(:user, id.to_s, cached) { User.new(self, @http.get_user(id)) }
    end

    # @return [Profile]
    def current_user(cached: true)
      data = cache(:user, :@me, cached: cached) { Profile.new(self, @http.get_current_user) }
      @cache_manager.set(:user, data.id, data)
    end

    # @return [Guild]
    def guild(id, cached: true)
      cache(:guild, id.to_s, cached: cached) { Guild.new(self, @http.get_guild(id)) }
    end

    # @return [Channel]
    def channel(id, cached: true)
      cache(:channel, id.to_s, cached: cached) { Channel.new(self, @http.get_channel(id)) }
    end

    # @return [Member]
    def member(guild_id, user_id, cached: true)
      cache(:member, [guild_id.to_s, user_id.to_s], cached: cached) do
        Member.new(self, @http.get_guild_member(guild_id, user_id), guild(guild_id, cached: cached))
      end
    end

    # @return [Role, nil]
    def role(role_id)
      @cache_manager.get(:role, role_id.to_s)
    end

    # @return [Emoji, nil]
    def emoji(emoji_id)
      @cache_manager.get(:emoji, emoji_id.to_s)
    end

    # @return [Webhook]
    def webhook(webhook_id, token: nil, cached: true)
      cache(:webhook, webhook_id.to_s, cached: cached) do
        data = if token
                 @http.get_webhook_with_token(webhook_id, token)
               else
                 @http.get_webhook(webhook_id)
               end
        Webhook.new(self, data)
      end
    end

    # @return [Invite]
    def invite(invite_code, cached: true)
      cache(:invite, invite_code, cached) do
        Invite.new(self, @http.get_invite(invite_code))
      end
    end

    def connect(async: false)
      @gateway.connect(async: async)
    end

    private

    def create_gateway(token:, options:)
      options[:url] ||= @http.get_gateway_bot[:url]
      Vox::Gateway::Client.new(**{ token: token }.merge(**options))
    end

    def setup_gateway_caching
      @gateway.on(:GUILD_CREATE, &method(:handle_guild_create))
      @gateway.on(:GUILD_UPDATE, &method(:handle_guild_update))
      @gateway.on(:GUILD_DELETE, &method(:handle_guild_delete))
      @gateway.on(:GUILD_ROLE_CREATE, &method(:handle_guild_role_create))

      @gateway.on(:CHANNEL_UPDATE, &method(:handle_channel_update))
      @gateway.on(:CHANNEL_CREATE, &method(:handle_channel_create))
      @gateway.on(:CHANNEL_DELETE, &method(:handle_channel_delete))
    end

    def handle_guild_create(data)
      guild_data = Guild.new(self, data)
      cache_upsert(:guild, data[:id], guild_data)

      emit(:GUILD_CREATE, guild(data[:id]) || guild_data)
    end

    def handle_guild_update(data)
      guild_data = Guild.new(self, data)
      cache_upsert(:guild, guild_data.id, guild_data)

      emit(:GUILD_UPDATE, guild(data[:id]) || guild_data)
    end

    def handle_guild_delete(data)
      guild_data = @cache_manager.get(:guild, data[:id])

      emit(:GUILD_DELETE, guild_data)
      @cache_manager.delete(:guild, data[:id])
    end

    def handle_guild_role_create(data)
      guild_data = guild(data[:guild_id])
      role_data = Role.new(self, data[:role])
      cache_upsert(:role, role_data[:id], role_data)
      guild_data.roles << role_data if guild_data

      emit(:GUILD_ROLE_CREATE, role(data[:id]) || role_data)
    end

    def handle_guild_role_update(data)
      role_data = Role.new(self, data)
      cache_upsert(:role, role_data)

      emit(:GUILD_ROLE_UPDATE, role(data[id]) || data)
    end

    def handle_guild_role_delete(data)
      role_data = role(data[:role_id]) || Role.new(self, data)
      guild_data = guild(data[:guild_id])
      guild_data.roles.delete(role_data)

      emit(:GUILD_ROLE_DELETE, role_data)
    end

    def handle_channel_create(data)
      channel_data = Channel.new(self, data)
      cache_upsert(:channel, data[:id], data)

      emit(:CHANNEL_CREATE, channel(data[:id]) || channel_data)
    end

    def handle_channel_update(data)
      channel_data = Channel.new(self, data)
      cache_upsert(:channel, data[:id], channel_data)

      emit(:CHANNEL_UPDATE, channel(data[:id]) || channel_data)
    end

    def handle_channel_delete(data)
      channel_data = Channel.new(data)
      @cache_manager.delete(:channel, data[:id])

      emit(:CHANNEL_DELETE, channel_data)
    end

    def handle_channel_pins_update(data)
      channel_data = channel(data[:channel_id])
      channel_data.update_data({ last_pin_timestamp: data[:last_pin_timestamp] })

      emit(:CHANNEL_PINS_UPDATE, channel_data)
    end
  end
end
