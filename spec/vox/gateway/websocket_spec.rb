# frozen_string_literal: true

require 'rspec'
require 'vox/gateway/websocket'

RSpec.describe Vox::Gateway::WebSocket do
  let(:ws) { described_class.new('wss://localhost') }
  let(:ws_with_driver) do
    websocket = described_class.new('wss://localhost')
    driver = instance_double('WebSocket::Driver::Client')
    websocket.instance_variable_set(:@driver, driver)
    websocket
  end

  describe '#connect' do
    context 'when not connected' do
      let(:inflate) do
        i = instance_double('Zlib::Inflate')
        allow(i).to receive(:reset)
        i
      end
      let(:socket) { instance_double('SSLSocket') }
      let(:driver) do
        d = instance_double('WebSocket::Driver::Client')
        allow(d).to receive(:state).and_return(:closed)
        d
      end

      before do
        allow(ws).to receive(:setup_driver).and_return(driver)
        allow(ws).to receive(:create_socket).and_return(instance_double('SSLSocket'))
        allow(ws).to receive(:read_loop)
        ws.instance_variable_set(:@driver, driver)
      end

      it 'resets the zlib buffer' do
        ws.instance_variable_set(:@inflate, inflate)
        ws.connect.join
        expect(inflate).to have_received(:reset)
      end

      it 'creates a socket' do
        ws.connect.join
        expect(ws).to have_received(:create_socket)
      end

      it 'sets the websocket driver up' do
        ws.connect.join
        expect(ws).to have_received(:setup_driver)
      end

      it 'creates a loop to read from the websocket' do
        ws.connect.join
        expect(ws).to have_received(:read_loop)
      end
    end
  end

  describe '#write' do
    let(:ws) do
      websocket = described_class.new('wss://localhost')
      socket = instance_double('SSLSocket')
      allow(socket).to receive(:write).with(anything).and_return(nil)
      websocket.instance_variable_set(:@socket, socket)
      websocket
    end

    it 'writes to the socket directly' do
      data = instance_double('String')
      ws.write(data)

      expect(ws.instance_variable_get(:@socket)).to have_received(:write).with(data)
    end
  end

  describe '#send' do
    let(:ws) do
      websocket = ws_with_driver
      allow(websocket.driver).to receive(:text).with(anything)
      websocket
    end

    it 'writes a text message frame' do
      data = instance_double('String')
      ws.send(data)
      expect(ws.driver).to have_received(:text).with(data)
    end
  end

  describe '#send_json' do
    let(:ws) do
      websocket = ws_with_driver
      allow(websocket.driver).to receive(:text).with(anything)
      websocket
    end

    it 'writes a text message frame' do
      string_data = instance_double('String', 'string_data')
      json_data = instance_double('String', 'json_data')
      allow(MultiJson).to receive(:dump).with(string_data).and_return(json_data)

      ws.send_json(string_data)

      expect(ws.driver).to have_received(:text).with(json_data)
    end
  end

  describe '#send_binary' do
    let(:ws) do
      websocket = ws_with_driver
      allow(websocket.driver).to receive(:binary).with(anything)
      websocket
    end

    it 'sends a binary frame' do
      data = instance_double('String')
      ws.send_binary(data)

      expect(ws.driver).to have_received(:binary).with(data)
    end
  end

  describe '#read' do
    let(:data) { instance_double('String') }
    let(:socket) do
      s = instance_double('SSLSocket')
      allow(s).to receive(:readpartial).with(instance_of(Integer)).and_return(data)
      s
    end
    let(:ws) do
      w = ws_with_driver
      allow(w.driver).to receive(:parse).with(anything)
      w.instance_variable_set(:@socket, socket)
      w
    end

    it 'sends data from the socket to the driver' do
      ws.read
      expect(ws.driver).to have_received(:parse).with(data)
    end
  end

  describe '#close' do
    let(:ws) do
      websocket = ws_with_driver
      allow(websocket.driver).to receive(:close).with(anything, anything)
      websocket
    end

    it 'sends a close frame' do
      reason = instance_double('String')
      close_code = instance_double('Integer')
      ws.close(reason, close_code)

      expect(ws.driver).to have_received(:close).with(reason, close_code)
    end
  end

  describe '#create_ssl_socket' do
    let(:ws) do
      described_class.new('wss://localhost', port: 443)
    end
    let(:socket) { instance_double('TCPSocket') }
    let(:ssl_socket) do
      s = instance_double('OpenSSL::SSL::SSLSocket')
      allow(s).to receive(:connect)
      s
    end

    before do
      allow(TCPSocket).to receive(:new).with('localhost', 443).and_return(socket)
      allow(OpenSSL::SSL::SSLSocket).to receive(:new).with(socket, anything).and_return(ssl_socket)
    end

    it 'creates an SSL socket from a TCPSocket' do
      ws.__send__(:create_ssl_socket)
      expect(OpenSSL::SSL::SSLSocket).to have_received(:new).with(socket, instance_of(OpenSSL::SSL::SSLContext))
    end
  end

  describe '#register_handlers' do
    let(:ws) do
      websocket = ws_with_driver
      allow(websocket.driver).to receive(:on).with(an_instance_of(Symbol))
      websocket
    end

    it 'registers on_open' do
      ws.__send__(:register_handlers)
      expect(ws.driver).to have_received(:on).with(:open)
    end

    it 'registers on_message' do
      ws.__send__(:register_handlers)
      expect(ws.driver).to have_received(:on).with(:message)
    end

    it 'registers on_close' do
      ws.__send__(:register_handlers)
      expect(ws.driver).to have_received(:on).with(:close)
    end
  end

  describe '#on_open' do
    it 'emits an `open` event' do
      allow(ws).to receive(:emit).with(:open)
      ws.__send__(:on_open, instance_double('WebSocket::Driver::OpenEvent'))
      expect(ws).to have_received(:emit).with(:open)
    end
  end

  describe '#on_message' do
    let(:ws) { described_class.new('wss://localhost', compression: false) }
    let(:str_data) { instance_double('String') }
    let(:data) do
      d = instance_double('Array')
      allow(d).to receive(:pack).with(anything).and_return(str_data)
      d
    end
    let(:event) do
      e = instance_double('WebSocket::Driver::MessageEvent')
      allow(e).to receive(:data).and_return(data)
      e
    end

    it 'emits a `message` event' do
      allow(data).to receive(:[]).and_return('{')
      allow(ws).to receive(:emit).with(:message, data)
      ws.__send__(:on_message, event)
      expect(ws).to have_received(:emit).with(:message, data)
    end

    context 'when compression is enabled' do
      let(:inflated_data) { instance_double('String') }
      let(:inflate) do
        instance_double('Zlib::Inflate').tap do |i|
          allow(i).to receive(:<<).with(str_data)
          allow(i).to receive(:inflate).with('').and_return(inflated_data)
        end
      end
      let(:ws) do
        described_class.new('wss://localhost').tap do |w|
          allow(w).to receive(:emit).with(:message, inflated_data)
          w.instance_variable_set(:@inflate, inflate)
        end
      end

      before { stub_const('ZLIB_SUFFIX', Vox::Gateway::WebSocket::ZLIB_SUFFIX) }

      it 'inflates the received data' do
        allow(inflated_data).to receive(:[]).and_return('{')
        allow(str_data).to receive(:end_with?).with(ZLIB_SUFFIX).and_return true
        allow(ws).to receive(:emit).with(:message, inflated_data)
        ws.__send__(:on_message, event)
        expect(ws).to have_received(:emit).with(:message, inflated_data)
      end

      it 'returns early if the zlib boundary is not hit' do
        allow(str_data).to receive(:end_with?).with(ZLIB_SUFFIX).and_return false
        ws.__send__(:on_message, event)
        expect(ws).not_to have_received(:emit)
      end
    end
  end

  describe '#on_close' do
    let(:code) { instance_double('Integer') }
    let(:reason) { instance_double('String') }
    let(:event) do
      instance_double('WebSocket::Driver::CloseEvent').tap do |e|
        allow(e).to receive(:code).and_return(code)
        allow(e).to receive(:reason).and_return(reason)
      end
    end

    it 'emits a close event' do
      allow(ws).to receive(:emit).with(any_args)
      ws.__send__(:on_close, event)
      expect(ws).to have_received(:emit).with(:close, { code: code, reason: reason })
    end
  end

  describe '#read_loop' do
    let(:ws) do
      w = ws_with_driver
      allow(w.driver).to receive(:state).and_return(:open, :closed)
      allow(w).to receive(:read)
      w
    end

    it 'calls read while the driver is not closed' do
      ws.__send__(:read_loop)
      expect(ws).to have_received(:read).once
    end

    it 'rescues from socket errors' do
      allow(ws.driver).to receive(:state).and_raise(SystemCallError.new('socket error'))
      expect { ws.__send__(:read_loop) }.not_to raise_error
    end

    it 'rescues from EOF errors' do
      allow(ws.driver).to receive(:state).and_raise(EOFError.new)
      expect { ws.__send__(:read_loop) }.not_to raise_error
    end
  end

  describe '#setup_driver' do
    let(:driver) do
      d = instance_double('WebSocket::Driver::Client')
      allow(d).to receive(:start)
      d
    end

    before do
      allow(ws).to receive(:register_handlers)
      allow(::WebSocket::Driver).to receive(:client).with(ws).and_return(driver)
    end

    it 'creates a driver' do
      ws.__send__(:setup_driver)
      expect(ws.driver).to be driver
    end

    it 'registers handlers' do
      ws.__send__(:setup_driver)
      expect(ws).to have_received(:register_handlers)
    end

    it 'starts the driver' do
      ws.__send__(:setup_driver)
      expect(driver).to have_received(:start)
    end
  end

  describe '#create_socket' do
    context 'when using WSS' do
      let(:ssl_socket) do
        s = instance_double('OpenSSL::SSL::SSLSocket')
        allow(s).to receive(:connect)
        s
      end

      before do
        ws.instance_variable_set(:@uri, instance_double('URI::Generic', scheme: 'wss'))
        allow(ws).to receive(:create_ssl_socket).and_return(ssl_socket)
      end

      it 'creates an SSL socket' do
        ws.__send__(:create_socket)
        expect(ws).to have_received(:create_ssl_socket)
      end

      it 'starts the SSL socket' do
        ws.__send__(:create_socket)
        expect(ssl_socket).to have_received(:connect)
      end
    end

    context 'when using WS' do
      let(:socket) { instance_double('TCPSocket') }
      let(:port) { instance_double('Integer') }
      let(:host) { instance_double('String') }

      before do
        ws.instance_variable_set(:@uri, instance_double('URI::Generic', scheme: 'ws', host: host))
        ws.instance_variable_set(:@port, port)
        allow(TCPSocket).to receive(:new).with(host, port)
      end

      it 'creates a TCPSocket' do
        ws.__send__(:create_socket)
        expect(TCPSocket).to have_received(:new).with(host, port)
      end
    end
  end
end
