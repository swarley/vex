# frozen_string_literal: true

require 'vox/gateway/websocket'
# require 'logging'

module Vox
  module Gateway
    class Client
      include EventEmitter

      DEFAULT_PROPERTIES = {
        '$os': Gem::Platform.local.os,
        '$browser': 'vox',
        '$device': 'vox'
      }.freeze
      OPCODES = {
        0 => :DISPATCH,
        1 => :HEARTBEAT,
        2 => :IDENTIFY,
        3 => :PRESENCE_UPDATE,
        4 => :VOICE_STATE_UPDATE,
        5 => :UNKNOWN,
        6 => :RESUME,
        7 => :RECONNECT,
        8 => :REQUEST_GUILD_MEMBERS,
        9 => :INVALID_SESSION,
        10 => :HELLO,
        11 => :HEARTBEAT_ACK
      }.tap { |ops| ops.merge!(ops.invert) }.freeze
      GATEWAY_VERSION = '6'

      Session = Struct.new(:id, :seq)

      # @param url [String] The url to use when connecting to the websocket. This can be
      #   retrieved from the API with {HTTP::Routes::Gateway#get_gateway_bot}.
      # @param token [String] The token to use for authorization.
      # @param port [Integer] The port to use when connecting. If `nil`, it will be inferred
      #   from the URL scheme (80 for `ws`, and 443 for `wss`).
      # @param encoding [:json] This only accepts `json` currently, but may support `:etf` in future versions.
      # @param compress [true, false] Whether to use `zlib-stream` compression.
      # @param shard [Array<Integer>] An array in the format `[ShardNumber, TotalShards]`.
      # @param large_threshold [Integer]
      # @param presence [Object]
      # @param intents [Integer]
      def initialize(url:, token:, port: nil, encoding: :json, compress: true, shard: [0, 1],
                     properties: DEFAULT_PROPERTIES, large_threshold: nil, presence: nil, intents: nil)
        uri = create_gateway_uri(url, port: port, encoding: encoding, compress: compress)
        
        @encoding = encoding
        raise ArgumentError, "Invalid gateway encoding" unless %i[json etf].include? @encoding

        require 'vox/etf' if @encoding == :etf

        @websocket = WebSocket.new(uri.to_s, port: uri.port, compression: compress)
        @identify_opts = {
          token: token, properties: properties, shard: shard,
          large_threshold: large_threshold, presence: presence, intents: intents
        }.compact
        @session = Session.new

        setup_handlers
      end

      def connect
        @websocket.connect
      end

      def join
        @websocket.thread.join
      end

      # Send a packet with the correct encoding. Only supports JSON currently.
      # @param op_code [Integer]
      # @param data [Hash]
      def send_packet(op_code, data)
        LOGGER.debug { "Sending #{op_code.is_a?(Symbol) ? op_code : OPCODES[op_code]} #{data || 'nil'}" }
        if encoding == :etf
          send_etf_packet(op_code, data)
        else
          send_json_packet(op_code, data)
        end
      end

      def request_guild_members(guild_id, query: nil, limit: 0, presences: nil,
                                user_ids: nil, nonce: nil)
        opts = {
          guild_id: guild_id, query: query, limit: limit, presences: presences,
          user_ids: user_ids, nonce: nonce
        }.compact

        send_packet(OPCODES[:REQUEST_GUILD_MEMBERS], opts)
      end

      def voice_state_update(guild_id:, channel_id:, self_mute: false, self_deaf: false)
        opts = {
          guild_id: guild_id, channel_id: channel_id, self_mute: self_mute,
          self_deaf: self_deaf
        }.compact

        send_packet(OPCODES[:VOICE_STATE_UPDATE], opts)
      end

      def presence_update(status:, afk: false, game: nil, since: nil)
        opts = { status: status, afk: afk, game: game, since: since }.compact
        send_packet(OPCODES[:PRESENCE_UPDATE], opts)
      end

      private

      def setup_handlers
        # Discord will contact us with HELLO first, so we don't need to hook into READY
        @websocket.on(:message, &method(:handle_message))
        @websocket.on(:close, &method(:handle_close))

        # Setup payload handlers
        on(:DISPATCH, &method(:handle_dispatch))
        on(:HEARTBEAT, &method(:handle_heartbeat))
        on(:RECONNECT, &method(:handle_reconnect))
        on(:INVALID_SESSION, &method(:handle_invalid_session))
        on(:HELLO, &method(:handle_hello))
        on(:HEARTBEAT_ACK, &method(:handle_heartbeat_ack))
        on(:READY, &method(:handle_ready))
      end


      # Create a URI from a gateway url and options
      # @param url [String]
      # @param port [Integer]
      # @param encoding [:json]
      # @param compress [true, false]
      # @return [URI::Generic]
      def create_gateway_uri(url, port: nil, encoding: :json, compress: true)
        compression = compress ? 'zlib-stream' : nil
        query = URI.encode_www_form(
          version: GATEWAY_VERSION, encoding: encoding, compress: compression
        )
        URI(url).tap do |u|
          u.query = query
          u.port = port
        end
      end

      # Send a JSON packet.
      # @param op_code [Integer]
      # @param data [Hash]
      def send_json_packet(op_code, data)
        payload = { op: op_code, d: data }

        @websocket.send_json(payload)
      end

      def send_etf_packet(op_code, data)
        payload = { op: op_code, d: data }
        @websocket.binary(Vox::ETF.encode(payload))
      end

      # Send an identify payload to discord, beginning a new session.
      def send_identify
        send_packet(OPCODES[:IDENTIFY], @identify_opts)
      end

      def send_resume
        send_packet(OPCODES[:RESUME],
                    { token: @identify_opts[:token], session_id: @session.id, seq: @session.seq })
      end

      # Send a heartbeat.
      def send_heartbeat
        @heartbeat_acked = false
        send_packet(OPCODES[:HEARTBEAT], @session.seq)
      end

      # Loop for
      def heartbeat_loop
        loop do
          send_heartbeat
          sleep @heartbeat_interval
          unless @heartbeat_acked
            LOGGER.error { 'Heartbeat was not acked, reconnecting.' }
            @websocket.close
            break
          end
        end
      end

      ##################################
      ##################################
      ##################################
      ##################################
      ####                          ####
      #### Internal event handlers  ####
      ####                          ####
      ##################################
      ##################################
      ##################################
      ##################################

      # Placeholder for when we can do etf
      def handle_message(data)
        if @encoding == :etf
          handle_etf_message(data)
        else
          handle_json_message(data)
        end
      end

      def handle_etf_message(data)
        data = Vox::ETF.decode(data)
        LOGGER.debug { "Emitting #{OPCODES[data[:op]]}" } if OPCODES[data[:op]] != :DISPATCH

        @session.seq = data[:s] if data[:s]
        op = OPCODES[data[:op]]

        emit(op, data)
      end

      def handle_json_message(json)
        data = MultiJson.load(json, symbolize_keys: true)
        # Don't announce DISPATCH events since we log it on the same level
        # in the dispatch handler.
        LOGGER.debug { "Emitting #{OPCODES[data[:op]]}" } if OPCODES[data[:op]] != :DISPATCH

        @session.seq = data[:s] if data[:s]
        op = OPCODES[data[:op]]

        emit(op, data)
      end

      def handle_dispatch(payload)
        LOGGER.debug { "Emitting #{payload[:t]}" }
        emit(payload[:t], payload)
      end

      def handle_hello(payload)
        LOGGER.info { 'Connected' }
        @heartbeat_interval = payload[:d][:heartbeat_interval] / 1000
        @heartbeat_thread = Thread.new { heartbeat_loop }
        if @session.seq
          send_resume
        else
          send_identify
        end
      end

      # Fired if the gateway requests that we send a heartbeat.
      def handle_heartbeat(_payload)
        send_packet(OPCODES[:HEARTBEAT], @session.seq)
      end

      def handle_ready(payload)
        @session.id = payload[:d][:session_id]
      end

      def handle_invalid_session(_payload)
        @session.seq = nil
        send_identify
      end

      def handle_reconnect(_payload)
        @websocket.close('Received reconnect', 4000)
      end

      def handle_heartbeat_ack(_payload)
        @heartbeat_acked = true
      end

      def handle_close(data)
        LOGGER.warn { "Websocket closed (#{data[:code]} #{data[:reason]})" }
        @heartbeat_thread&.kill
        should_reconnect = false

        case data[:code]
        when 4000
          LOGGER.error { 'Disconnected from an unknown error.' }
        when 4001
          LOGGER.error { 'Sent an invalid opcode or payload.' }
        when 4002
          LOGGER.error { 'Sent a payload that could not be decoded.' }
        when 4003
          LOGGER.error { 'A payload was sent before identifying.' }
        when 4004
          LOGGER.error { 'An invalid token was used to identify.' }
        when 4005
          LOGGER.error { 'More than one identify was sent.' }
        # Invalid seq when resuming, or session timed out
        when 4007, 4009
          LOGGER.error { 'Invalid session, reconnecting.' }
          @session = Session.new
          should_reconnect = true
        when 4008
          LOGGER.error { 'Gateway rate limit exceeded.' }
        when 4010
          LOGGER.fatal { 'Invalid shard sent when identifying' }
        when 4011
          LOGGER.fatal { 'Sharding is required, see https://discord.com/developers/docs/topics/gateway#sharding' }
        when 4012
          LOGGER.fatal { 'An invalid API version was used' }
        when 4013
          LOGGER.fatal { 'Invalid intents were supplied.' }
        when 4014
          LOGGER.fatal { 'A privileged intent which has not been enabled was supplied.' }
        else
          should_reconnect = true
        end

        connect if should_reconnect
      end

      # @!visibility private
      LOGGER = Logging.logger[self]
    end
  end
end
