# frozen_string_literal: true

module Vox
  # Represents a code that when used, adds a user to a guild or group DM channel.
  class Invite < APIObject
    # @!attribute [r] code
    #   @return [String] The invite code.
    attr_reader :code

    # @!attribute [r] guild
    #   @return [Guild] The guild this invite is for.
    attr_reader :guild

    # @!attribute [r] channel
    #   @return [Channel] The channel this invite is for.
    attr_reader :channel

    # @!attribute [r] inviter
    #   @return [User, nil] The user who created the invite.
    attr_reader :inviter

    # @!attribute [r] target_user
    #   @return [User, nil] The user this invite is intended for.
    attr_reader :target_user

    # @!attribute [r] target_user_type
    #   @return [Integer, nil] The type of user target for this invite.
    attr_reader :target_user_type

    # @!attribute [r] approximate_presence_count
    #   @return [Integer, nil] The approximate count of online members.
    attr_reader :approximate_presence_count

    # @!attribute [r] approximate_member_count
    #   @return [Integer, nil] The approximate count of total members.
    attr_reader :approximate_member_count

    # Check if the target is a stream.
    def stream_target?
      @target_user_type == 1
    end

    # Delete this invite.
    def delete
      @client.http.delete_invite(@code)
    end

    def update_data(data)
      inviter = data[:inviter]
      data[:inviter] = @client.cache_upsert(:user, inviter[:id], User.new(@client, inviter)) if inviter

      target = data[:target_user]
      data[:target_user] = @client.cache_upsert(:user, target[:id], User.new(@client, target)) if target

      guild = data[:guild]
      data[:guild] = @client.cache_upsert(:guild, guild[:id], Guild.new(@client, guild)) if guild

      channel = data[:channel]
      data[:channel] = @client.cache_upsert(:channel, channel[:id], Channel.new(@client, channel)) if channel

      created_at = data[:created_at]
      data[:created_at] = Time.iso8601(created_at) if created_at

      super
    end
  end
end
