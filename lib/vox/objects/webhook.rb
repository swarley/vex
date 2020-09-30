# frozen_string_literal: true

module Vox
  # Webhooks are a low-effort way to post messages to channels in Discord.
  class Webhook < APIObject
    # @return [String]
    attr_reader :id

    # @return [Integer]
    attr_reader :type

    # @return [String, nil]
    attr_reader :guild_id

    # @return [User]
    attr_reader :user

    # @return [String]
    attr_reader :token

    # @!group Modifiable Attributes

    # @!attribute [rw] channel_id
    # @return [String]
    modifiable :channel_id

    # @!attribute [rw] name
    # @return [String, nil]
    modifiable :name

    # @!attribute [rw] avatar
    # @return [String, nil]
    modifiable :avatar

    # @!endgroup

    def initialize(client, data)
      super

      return unless (user_data = data[:user])

      @user = @client.cache_upsert(:user, user_data[:id], User.new(client, user_data))
    end

    # Modify this webhook.
    # @param name [String, nil] The new name for the webhook.
    # @param avatar [String, nil] The avatar data for this webhook. `nil` to remove.
    # @param channel_id [String, nil] The channel ID this webhook should post in.
    def modify(name: :undef, avatar: :undef, channel_id: :undef)
      @client.http.modify_webhook(@id, name: name, avatar: avatar, channel_id: channel_id)
    end

    # Delete this webhook.
    def delete
      if @token
        @client.http.delete_webhook_with_token(@id, @token)
      else
        @client.http.delete_webhook(@id)
      end
    end

    # TODO
    def execute(**hash)
      @client.http.execute_webhook(@id, @token, **hash)
    end

    # @!attribute [r] channel
    # @return [Channel, nil]
    def channel
      @client.channel(@channel_id)
    end

    # @!attribute [r] guild
    # @return [Guild, nil]
    def guild
      @client.guild(@guild_id)
    end

    # @!group Type Checking

    # Check if the webhook is a standard webhook.
    # @return [true, false]
    def incoming?
      @type == 1
    end

    # Check if the webhook is a channel following webhook.
    # @return [true, false]
    def channel_follower?
      @type == 2
    end

    # @!endgroup
  end
end
