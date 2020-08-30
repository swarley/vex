# frozen_string_literal: true

require 'event_emitter'
require 'logging'
require 'multi_json'
require 'websocket/driver'
require 'socket'
require 'openssl'
require 'uri'
require 'zlib'

module Vox
  # Module containing the gateway component.
  module Gateway
    # Websocket that handles data interchange for {Vox::Gateway::Client}.
    class WebSocket
      include EventEmitter

      # Zlib boundary used for separating messages split into multiple frames.
      ZLIB_SUFFIX = "\x00\x00\xFF\xFF".b.freeze

      attr_reader :url, :thread, :driver

      def initialize(url, port: nil, compression: true)
        @url = url
        @uri = URI.parse(url)
        @port = port || @uri.scheme == 'wss' ? 443 : 80
        @inflate = Zlib::Inflate.new if compression
      end

      # @!method on(key, data)
      #   @overload on('open', &block)
      #     Emitted when the websocket finishes its connecting process.
      #   @overload on('message', &block)
      #     Emitted when a message is parsed from the websocket.
      #     @yieldparam [String] data The received message.
      #   @overload on('close', &block)
      #     Emitted when the websocket connection closes.
      #     @yieldparam [Integer] code The given close code.
      #     @yieldparam [String, nil] reason The reason the websocket was closed.

      # Connect to the websocket server.
      # @return [Thread] The thread handling the read loop.
      def connect
        # Maybe close and connect in the future instead?
        raise 'Unable to connect while driver is open. Please `#close` first' if @driver && @driver.state != :closed

        # Flush the zlib buffer
        @inflate&.reset

        # Create a socket connection to the URL
        @socket = create_socket

        # Initialize the websocket driver
        setup_driver

        # Read until our websocket closes.
        Thread.new { read_loop }
      end

      # Send a `text` message.
      # @param message [String] The `text` message to write to the websocket.
      # @return [true, false] Whether the message was sent successfully.
      def send(message)
        LOGGER.info { "[OUT] #{message} " }
        @driver.text(message)
      end

      # Serialize a hash to send as a `text` message.
      # @param hash [Hash] The hash to serialize and send as a `text` message.
      # @return [true, false] Whether the message was sent successfully.
      def send_json(hash)
        data = MultiJson.dump(hash)
        send(data)
      end

      # Send a `binary` frame.
      # @param data [String] The binary data to write to the websocket.
      # @return [true, false] Whether the data was send successfully.
      def send_binary(data)
        @driver.binary(data)
      end

      # @!visibility private
      # @param data [String] The data to write to the socket.
      def write(data)
        @socket.write(data)
      end

      # @!visibility private
      # @return [nil]
      def read
        @driver.parse(@socket.readpartial(4096))
      end

      # Close the websocket connection.
      # @param reason [String] The reason for closing the websocket.
      # @param code [Integer] The code to close the websocket with.
      # @return [true, false] Whether the websocket closed successfully.
      def close(reason = nil, code = 1000)
        @driver.close(reason, code)
      end

      private

      # Read from the socket until the websocket driver
      # reports as closed.
      def read_loop
        read until @driver.state == :closed
      end

      def setup_driver
        @driver = ::WebSocket::Driver.client(self)
        register_handlers
        @driver.start
      end

      # Create a socket, create an SSL socket instead for
      # wss.
      # @return [TCPSocket, SSLSocket]
      def create_socket
        if @uri.scheme == 'wss'
          create_ssl_socket.tap(&:connect)
        else
          TCPSocket.new(@uri.host, @port)
        end
      end

      # Create an SSL socket for WSS.
      def create_ssl_socket
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.set_params ssl_version: :TLSv1_2

        socket = TCPSocket.new(@uri.host, @port)
        OpenSSL::SSL::SSLSocket.new(socket, ctx)
      end

      # Register the base handlers.
      def register_handlers
        @driver.on(:open, &method(:on_open))
        @driver.on(:message, &method(:on_message))
        @driver.on(:close, &method(:on_close))
      end

      # Handle open events.
      def on_open(_event)
        LOGGER.info { 'Connection open' }
        emit(:open)
      end

      # Handle parsed message events.
      def on_message(event)
        LOGGER.debug { '[IN] Frame received' }
        data = if @inflate
                 packed = event.data.pack('c*')
                 @inflate << packed
                 return unless packed.end_with?(ZLIB_SUFFIX)

                 @inflate.inflate('')
               else
                 event.data
               end

        LOGGER.debug { "[IN] #{data}" }
        emit(:message, data)
      end

      # Handle close events.
      def on_close(event)
        LOGGER.info { "WebSocket is closing (#{event.code}) #{event.reason}" }
        emit(:close, { code: event.code, reason: event.reason })
      end

      # The logger used for output.
      LOGGER = Logging.logger[self]
    end
  end
end
