# frozen_string_literal: true

require 'vox/gateway/websocket'
require 'logging'

module Vox
  module Gateway
    # A client for receiving and writing data from the gateway.
    # The client uses an emitter pattern for emitting and registering events.
    # @example
    #   client.on(:MESSAGE_CREATE) do |payload|
    #     puts "Hello!" if payload[:content] == "hello"
    #   end
    class Client
      include EventEmitter

      # @!visibility private
      # The default properties for the identify packet
      DEFAULT_PROPERTIES = {
        '$os': Gem::Platform.local.os,
        '$browser': 'vox',
        '$device': 'vox'
      }.freeze

      # @!visibility private
      # A hash of opcodes => op_names, as well as op_names => opcodes.
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

      # The gateway version to request.
      GATEWAY_VERSION = '8'

      # Class that holds information about a session.
      Session = Struct.new(:id, :seq)

      # @return [Session] The connection's session information.
      attr_reader :session

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
        raise ArgumentError, 'Invalid gateway encoding' unless %i[json etf].include? @encoding

        if @encoding == :etf
          begin
            require 'vox/etf'
          rescue LoadError
            Logging.logger[self].error { 'ETF parsing lib not found. Please install vox-etf to use ETF encoding.' }
            raise Vox::Error.new('ETF lib not found')
          end
        end

        @websocket = WebSocket.new(uri.to_s, port: uri.port, compression: compress)
        @identify_opts = {
          token: token, properties: properties, shard: shard,
          large_threshold: large_threshold, presence: presence, intents: intents
        }.compact
        @session = Session.new
        @should_reconnect = Queue.new
        setup_handlers
      end

      # @!method on(event, &block)
      #   Register an event handler for a GATEWAY event, or DISPATCH event.
      #   When registering an event corresponding to an opcode, the full payload
      #   is yielded. When registering a DISPATCH type, only the data portion
      #   of the payload is provided.

      # Connect the websocket to the gateway.
      def connect(async: false)
        @ws_thread = Thread.new do
          loop do
            @websocket.connect
            @websocket.thread.join
            break unless @should_reconnect.shift
          end
        end
        async ? @ws_thread : @ws_thread.join
      end

      # Close the websocket.
      # @param code [Integer] The close code.
      # @param reason [String] The reason for closing.
      def close(reason = nil, code = 1000, reconnect: false)
        @ws_thread.kill unless reconnect
        @websocket.close(reason, code)
        @websocket.thread.join unless reconnect
      end

      # Send a packet with the correct encoding. Only supports JSON currently.
      # @param op_code [Integer]
      # @param data [Hash]
      def send_packet(op_code, data)
        LOGGER.debug { "Sending #{op_code.is_a?(Symbol) ? op_code : OPCODES[op_code]} #{data || 'nil'}" }
        if @encoding == :etf
          send_etf_packet(op_code, data)
        else
          send_json_packet(op_code, data)
        end
      end

      # Request a guild member chunk, used to build a member cache.
      # @param guild_id [String, Integer]
      # @param query
      # @param limit [Integer]
      # @param presences
      # @param user_ids [Array<String, Integer>]
      # @param nonce [String, Integer]
      def request_guild_members(guild_id, query: nil, limit: 0, presences: nil,
                                user_ids: nil, nonce: nil)
        opts = {
          guild_id: guild_id, query: query, limit: limit, presences: presences,
          user_ids: user_ids, nonce: nonce
        }.compact

        send_packet(OPCODES[:REQUEST_GUILD_MEMBERS], opts)
      end

      # Send a voice state update, used for establishing voice connections.
      # @param guild_id [String, Integer]
      # @param channel_id [String, Integer]
      # @param self_mute [true, false]
      # @param self_deaf [true, false]
      def voice_state_update(guild_id, channel_id, self_mute: false, self_deaf: false)
        opts = {
          guild_id: guild_id, channel_id: channel_id, self_mute: self_mute,
          self_deaf: self_deaf
        }.compact

        send_packet(OPCODES[:VOICE_STATE_UPDATE], opts)
      end

      # Update the bot's status.
      # @param status [String] The user's new status.
      # @param afk [true, false] Whether or not the client is AFK.
      # @param game [Hash<Symbol, Object>, nil] An [activity object](https://discord.com/developers/docs/topics/gateway#activity-object).
      # @param since [Integer, nil] Unix time (in milliseconds) of when the client went idle.
      def presence_update(status:, afk: false, game: nil, since: nil)
        opts = { status: status, afk: afk, game: game, since: since }.compact
        send_packet(OPCODES[:PRESENCE_UPDATE], opts)
      end

      private

      # Add internal event handlers
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

      # Send an ETF packet.
      # @param op_code [Integer]
      # @param data [Hash]
      def send_etf_packet(op_code, data)
        payload = { op: op_code, d: data }
        @websocket.send_binary(Vox::ETF.encode(payload))
      end

      # Send an identify payload to discord, beginning a new session.
      def send_identify
        send_packet(OPCODES[:IDENTIFY], @identify_opts)
      end

      # Send a resume payload to discord, attempting to resume an existing
      # session.
      def send_resume
        send_packet(OPCODES[:RESUME],
                    { token: @identify_opts[:token], session_id: @session.id, seq: @session.seq })
      end

      # Send a heartbeat.
      def send_heartbeat
        @heartbeat_acked = false
        send_packet(OPCODES[:HEARTBEAT], @session.seq)
      end

      # A loop that handles sending and receiving heartbeats from the gateway.
      def heartbeat_loop
        loop do
          send_heartbeat
          sleep @heartbeat_interval
          next if @heartbeat_acked

          LOGGER.error { 'Heartbeat was not acked, reconnecting.' }
          @websocket.close
          break
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

      # Handle a message from the websocket.
      # @param data [String] The message data.
      def handle_message(data)
        if @encoding == :etf
          handle_etf_message(data)
        else
          handle_json_message(data)
        end
      end

      # Handle an ETF message, decoding it and emitting an event.
      # @param data [String] The ETF data.
      def handle_etf_message(data)
        data = Vox::ETF.decode(data)
        LOGGER.debug { "Emitting #{OPCODES[data[:op]]}" } if OPCODES[data[:op]] != :DISPATCH

        @session.seq = data[:s] if data[:s]
        op = OPCODES[data[:op]]

        emit(op, data)
      end

      # Handle a JSON message, decoding it and emitting an event.
      # @param json [String] The JSON data.
      def handle_json_message(json)
        data = MultiJson.load(json, symbolize_keys: true)
        # Don't announce DISPATCH events since we log it on the same level
        # in the dispatch handler.
        LOGGER.debug { "Emitting #{OPCODES[data[:op]]}" } if OPCODES[data[:op]] != :DISPATCH

        @session.seq = data[:s] if data[:s]
        op = OPCODES[data[:op]]

        emit(op, data)
      end

      # Handle a dispatch event, extracting the event name and emitting an event.
      # @param payload [Hash<Symbol, Object>] The decoded payload's `data` field.
      def handle_dispatch(payload)
        LOGGER.debug { "Emitting #{payload[:t]}" }
        emit(payload[:t], payload[:d])
      end

      # Handle a hello event, beginning the heartbeat loop and identifying or
      # resuming.
      # @param payload [Hash<Symbol, Object>] The decoded payload.
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
      # @param _payload [Object] The received payload, not used in this method.
      def handle_heartbeat(_payload)
        send_packet(OPCODES[:HEARTBEAT], @session.seq)
      end

      # Set session information from the ready payload.
      # @param payload [Object] The received ready payload.
      def handle_ready(payload)
        @session.id = payload[:session_id]
      end

      # @param _payload [Object] The received payload, not used in this method.
      def handle_invalid_session(_payload)
        @session.seq = nil
        send_identify
      end

      # @param _payload [Object] The received payload, not used in this method.
      def handle_reconnect(_payload)
        @websocket.close('Received reconnect', 4000)
      end

      # Handle a heartbeat acknowledgement from the gateway.
      # @param _payload [Object] The received payload, not used in this method.
      def handle_heartbeat_ack(_payload)
        @heartbeat_acked = true
      end

      # Handle a close event from the websocket.
      # @param data [Hash{:code => Integer, :reason => String}]
      def handle_close(data)
        LOGGER.warn { "Websocket closed (#{data[:code]} #{data[:reason]})" }
        @heartbeat_thread&.kill
        reconnect = true

        case data[:code]
        # Invalid seq when resuming, or session timed out
        when 4007, 4009
          LOGGER.error { 'Invalid session, reconnecting.' }
          @session = Session.new
        when 4003, 4004, 4011
          LOGGER.fatal { data[:reason] }
          reconnect = false
        else
          LOGGER.error { data[:reason] } if data[:reason]
        end

        @should_reconnect << reconnect
      end

      # @!visibility private
      # The logger for Vox::Gateway::Client
      LOGGER = Logging.logger[self]
    end
  end
end
