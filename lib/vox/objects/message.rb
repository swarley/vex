# frozen_string_literal: true

require 'vox/objects/api_object'

module Vox
  # A message sent in a channel.
  class Message < APIObject
    # Flags that give information about a message.
    # @note `suppress_embeds` can me modified with {#suppress_embeds=}
    #   or {#modify}. This requires the `MANAGE_MESSAGES` permission.
    FLAGS = {
      crossposted: 1 << 0,
      is_crosspost: 1 << 1,
      suppress_embeds: 1 << 2,
      source_message_deleted: 1 << 3,
      urgent: 1 << 4
    }.freeze

    # @!group Flags

    # @!method crossposted?
    #   @return [true, false]
    # @!method is_crosspost?
    #   @return [true, false]
    # @!method suppress_embeds?
    #   @return [true, false]
    # @!method source_message_deleted?
    #   @return [true, false]
    # @!method urgent?
    #   @return [true, false]
    flags :@flags, **FLAGS

    # @!endgroup

    # @!attribute [r] id
    #   @return [true, false]
    attr_reader :id
    alias id? id

    # @!attribute [r] channel_id
    #   @return [String]
    attr_reader :channel_id

    # @!attribute [r] guild_id
    #   @return [String]
    attr_reader :guild_id

    # @!attribute [r] author
    #   @return [User]
    attr_reader :author

    # @!attribute [r] member
    #   @return [Member, nil]
    attr_reader :member

    # @!attribute [r] content
    #   @return [String]
    attr_reader :content

    # @!attribute [r] timestamp
    #   @return [Time]
    attr_reader :timestamp

    # @!attribute [r] edited_timestamp
    #   @return [Time]
    attr_reader :edited_timestamp

    # @!attribute [r] tts
    #   @return [true, false]
    attr_reader :tts
    alias tts? tts

    # @!attribute [r] mention_everyone
    #   @return [true, false]
    attr_reader :mention_everyone
    alias mention_everyone? mention_everyone

    # @!attribute [r] mentions
    #   @return [Array<UserMention>]
    attr_reader :mentions

    # @!attribute [r] mention_roles
    #   @return [Array<Role>, nil]
    attr_reader :mention_roles

    # @!attribute [r] mention_channels
    #   @return [Array<ChannelMention>, nil]
    attr_reader :mention_channels

    # @!attribute [r] attachments
    #   @return [Array<Attachment>]
    attr_reader :attachments

    # @!attribute [r] embeds
    #   @return [Array<Embed>]
    attr_reader :embeds

    # @!attribute [r] reactions
    #   @return [Array<Reaction>, nil]
    attr_reader :reactions

    # @!attribute [r] nonce
    #   @return [String, Integer]
    attr_reader :nonce

    # @!attribute [r] pinned
    #   @return [true, false]
    attr_reader :pinned
    alias pinned? pinned

    # @!attribute [r] webhook_id
    #   @return [String, nil]
    attr_reader :webhook_id

    # @!attribute [r] type
    #   @return [Integer]
    attr_reader :type

    # @!attribute [r] activity
    #   @return [Activity, nil]
    attr_reader :activity

    # @!attribute [r] application
    #   @return [Application, nil]
    attr_reader :application

    # @!attribute [r] message_reference
    #   @return [Reference, nil]
    attr_reader :message_reference

    # @!attribute [r] flags
    #   @return [Integer, nil]
    attr_reader :flags

    # @!group Modifiable Attributes

    # @!attribute [rw] content
    # @return [String] The message content.
    modifiable :content

    # @!attribute [rw] embed
    # @return [Embed] Embedded rich content.
    modifiable :embed

    # @!attribute [rw] allowed_mentions
    # @return [AllowedMentions]
    modifiable :allowed_mentions

    # @!attribute [rw] flags
    # @return [Integer]
    modifiable :flags

    # @!endgroup

    # @param value [true, false]
    # @return [true, false]
    def suppress_embeds=(value)
      return if value == suppress_embeds?

      new_flags = value ? (@flags | FLAGS[:suppress_embeds]) : (@flags ^ FLAGS[:suppress_embeds])
      data = modify(flags: new_flags)
      update_data(data)
    end

    # Send a message in the same channel as this message.
    # @return [Message] The created message.
    def reply(**hash)
      data = @client.http.create_message(@channel_id, **hash)
      Message.new(@client, data)
    end

    # @param content [String]
    # @param embed [Embed, Hash]
    # @param flags [Integer]
    def modify(content: :undef, embed: :undef, flags: :undef)
      @client.http.edit_message(@channel_id, @id, content: content, embed: embed, flags: flags)
    end
    alias edit modify

    # @!visibility private
    def update_data(data)
      if data.include? :timestamp
        ts = data[:timestamp]
        data[:timestamp] = ts ? Time.iso8601(ts) : nil
      end

      if data.include? :edited_timestamp
        ts = data[:edited_timestamp]
        @edited_timestamp = ts ? Time.iso8601(ts) : nil
      end

      super
    end
  end
end
