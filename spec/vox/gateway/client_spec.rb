# frozen_string_literal: true

require 'vox/gateway/client'
require 'vox/etf'

RSpec.describe Vox::Gateway::Client do
  let(:url) { 'wss://localhost' }
  let(:token) { instance_double('String', 'token') }
  let(:ws) do
    t = instance_double('Thread', 'ws_thread')
    allow(t).to receive(:join)
    instance_double('Vox::Gateway::WebSocket').tap do |w|
      allow(w).to receive(:on).with(any_args)
      allow(w).to receive(:connect)
      allow(w).to receive(:thread).and_return(t)
    end
  end
  let(:client) { described_class.new(url: url, token: token, encoding: :json) }

  before do
    allow(Vox::Gateway::WebSocket).to receive(:new).and_return(ws)
  end

  describe '#initialize' do
    before do
      allow(Vox::Gateway::WebSocket).to receive(:new).and_return(ws)
    end

    it 'creates a new session' do
      obj = described_class.new(url: url, token: token)
      sess = obj.instance_variable_get(:@session)
      expect(sess).to be_instance_of Vox::Gateway::Client::Session
    end

    it 'adds default websocket handlers' do
      described_class.new(url: url, token: token)
      expect(ws).to have_received(:on).twice
    end

    it 'adds default client handlers' do
      obj = described_class.new(url: url, token: token)
      expect(obj.__events).not_to be_empty
    end

    # rubocop:disable RSpec/AnyInstance
    context 'when encoding is :etf' do
      it 'requires vox-etf' do
        allow_any_instance_of(described_class).to receive(:require)
        client = described_class.new(url: url, token: token, encoding: :etf)
        expect(client).to have_received(:require).with('vox/etf')
      end

      it 'raises an error if vox-etf is not installed' do
        allow_any_instance_of(described_class).to receive(:require).and_raise(LoadError)
        expect { described_class.new(url: url, token: token, encoding: :etf) }.to raise_error(Vox::Error)
      end
    end
    # rubocop:enable RSpec/AnyInstance
  end

  describe '#setup_handlers' do
    let(:client) do
      allow(ws).to receive(:on)
      described_class.new(url: url, token: token).tap do |c|
        allow(c).to receive(:send_packet)
        allow(c).to receive(:on).with(anything).and_return nil
      end
    end

    it 'adds gateway event handles' do
      client
      %i[message close].each do |type|
        expect(ws).to have_received(:on).with(type)
      end
    end

    it 'adds websocket handlers' do
      %i[DISPATCH HEARTBEAT RECONNECT INVALID_SESSION HELLO HEARTBEAT_ACK].each do |type|
        handler = client.__events.find { |x| x[:type] == type }
        expect(handler).not_to be_nil
      end
    end
  end

  describe '#connect' do
    let(:thread) { instance_double('Thread') }

    before do
      allow(client.instance_variable_get(:@should_reconnect)).to receive(:shift).and_return(false)
      allow(ws.thread).to receive(:join)
      allow(Thread).to receive(:new).and_yield.and_return(thread)
      allow(thread).to receive(:join)
    end

    it 'starts a connection loop' do
      client.connect
      expect(ws).to have_received(:connect)
    end

    it 'joins the thread when not async' do
      client.connect
      expect(ws.thread).to have_received(:join)
    end

    it 'checks if it should reconnect' do
      client.connect
      expect(client.instance_variable_get(:@should_reconnect)).to have_received(:shift)
    end

    it 'blocks when async is false' do
      client.connect(async: false)
      expect(thread).to have_received(:join)
    end

    it 'does not block when async is true' do
      client.connect(async: true)
      expect(thread).not_to have_received(:join)
    end
  end

  describe '#close' do
    let(:ws_thread) do
      instance_double('Thread', 'ws_thread').tap do |thread|
        allow(thread).to receive(:kill)
      end
    end

    before do
      allow(ws).to receive(:close)
      allow(ws.thread).to receive(:join)
      client.instance_variable_set(:@ws_thread, ws_thread)
    end

    it 'sends a close frame' do
      client.close(reconnect: true)
      expect(ws).to have_received(:close)
    end

    it 'kills the websocket thread if not reconnecting' do
      client.close
      expect(ws_thread).to have_received(:kill)
    end

    it 'joins to the websocket thread' do
      client.close
      expect(ws.thread).to have_received(:join)
    end
  end

  describe '#request_guild_members' do
    let(:client) do
      described_class.new(url: url, token: token).tap do |c|
        allow(c).to receive(:send_packet)
      end
    end
    let(:guild_id) { instance_double('String', 'guild_id') }

    it 'sends a REQUEST_GUILD_MEMBERS packet' do
      client.request_guild_members(guild_id)
      expect(client).to have_received(:send_packet).with(
        Vox::Gateway::Client::OPCODES[:REQUEST_GUILD_MEMBERS],
        anything
      )
    end
  end

  describe '#voice_state_update' do
    let(:client) do
      described_class.new(url: url, token: token).tap do |c|
        allow(c).to receive(:send_packet)
      end
    end
    let(:guild_id) { instance_double('String', 'guild_id') }
    let(:channel_id) { instance_double('String', 'channel_id') }

    it 'sends a VOICE_STATE_UPDATE packet' do
      client.voice_state_update(guild_id, channel_id)
      expect(client).to have_received(:send_packet).with(
        Vox::Gateway::Client::OPCODES[:VOICE_STATE_UPDATE],
        hash_including(guild_id: guild_id, channel_id: channel_id)
      )
    end
  end

  describe '#presence_update' do
    let(:client) do
      described_class.new(url: url, token: token).tap do |c|
        allow(c).to receive(:send_packet)
      end
    end
    let(:status) { instance_double('String', 'status') }

    it 'sends a PRESENCE_UPDATE packet' do
      client.presence_update(status: status)
      expect(client).to have_received(:send_packet).with(
        Vox::Gateway::Client::OPCODES[:PRESENCE_UPDATE],
        hash_including(status: status)
      )
    end
  end

  describe '#create_gateway_uri' do
    let(:client) do
      described_class.new(url: url, token: token).tap do |c|
        allow(c).to receive(:send_packet)
      end
    end
    let(:version) { Vox::Gateway::Client::GATEWAY_VERSION }

    it 'returns a URI object' do
      uri = client.__send__(:create_gateway_uri, 'wss://localhost/')
      expect(uri).to be_instance_of URI::Generic
    end

    it 'formats the query parameters' do
      uri = client.__send__(:create_gateway_uri, 'wss://localhost/')
      expect(uri.to_s).to eq "wss://localhost/?version=#{version}&encoding=json&compress=zlib-stream"
    end
  end

  describe '#send_packet' do
    let(:op_code) { instance_double('Integer', 'op_code') }
    let(:data) { instance_double('String', 'data') }

    context 'when the encoding is :json' do
      before do
        client.instance_variable_set(:@encoding, :json)
        allow(client).to receive(:send_json_packet)
      end

      it 'calls send_json_packet' do
        client.send_packet(op_code, data)
        expect(client).to have_received(:send_json_packet).with(op_code, data)
      end
    end

    context 'when the encoding is :etf' do
      before do
        client.instance_variable_set(:@encoding, :etf)
        allow(client).to receive(:send_etf_packet)
      end

      it 'calls send_etf_packet' do
        client.send_packet(op_code, data)
        expect(client).to have_received(:send_etf_packet).with(op_code, data)
      end
    end
  end

  describe '#send_json_packet' do
    let(:client) do
      described_class.new(url: url, token: token).tap do |c|
        allow(c).to receive(:send_packet)
      end
    end
    let(:op) { instance_double('String', 'op') }
    let(:data) { instance_double('Hash', 'data') }

    before { allow(ws).to receive(:send_json) }

    it 'tells the websocket to send a json payload' do
      client.__send__(:send_json_packet, op, data)
      expect(ws).to have_received(:send_json).with({ op: op, d: data })
    end
  end

  describe '#send_etf_packet' do
    let(:op) { instance_double('String', 'op') }
    let(:data) { instance_double('Hash', 'data') }
    let(:payload) { { d: data, op: op } }
    let(:enc_data) { instance_double('String', 'enc_data') }

    before do
      allow(ws).to receive(:send_binary)
      allow(Vox::ETF).to receive(:encode).with(payload).and_return(enc_data)
    end

    it 'tells the websocket to send a json payload' do
      client.__send__(:send_etf_packet, op, data)
      expect(ws).to have_received(:send_binary).with(enc_data)
    end
  end

  describe '#send_identify' do
    let(:client) do
      described_class.new(url: url, token: token).tap do |c|
        allow(c).to receive(:send_packet)
      end
    end

    it 'sends an IDENTIFY packet' do
      client.__send__(:send_identify)
      expect(client).to have_received(:send_packet).with(
        Vox::Gateway::Client::OPCODES[:IDENTIFY],
        anything
      )
    end
  end

  describe '#send_resume' do
    let(:client) do
      described_class.new(url: url, token: token).tap do |c|
        allow(c).to receive(:send_packet)
      end
    end

    it 'sends a RESUME packet' do
      client.__send__(:send_resume)
      expect(client).to have_received(:send_packet).with(
        Vox::Gateway::Client::OPCODES[:RESUME],
        anything
      )
    end
  end

  describe '#send_heartbeat' do
    let(:client) do
      described_class.new(url: url, token: token).tap do |c|
        allow(c).to receive(:send_packet)
      end
    end

    it 'sends a HEARTBEAT packet' do
      client.__send__(:send_heartbeat)
      expect(client).to have_received(:send_packet).with(
        Vox::Gateway::Client::OPCODES[:HEARTBEAT],
        anything
      )
    end
  end

  describe '#heartbeat_loop' do
    let(:client) do
      described_class.new(url: url, token: token).tap do |c|
        allow(c).to receive(:send_heartbeat)
        allow(ws).to receive(:close)
        c.instance_variable_set(:@heartbeat_interval, 0)
        c.instance_variable_set(:@heartbeat_acked, false)
      end
    end

    it 'sends a heartbeat' do
      client.__send__(:heartbeat_loop)
      expect(client).to have_received(:send_heartbeat)
    end

    it 'closes when the heartbeat is not acked' do
      client.__send__(:heartbeat_loop)
      expect(ws).to have_received(:close)
    end
  end

  describe '#handle_message' do
    let(:data) { instance_double('String') }

    context 'when the encoding is json' do
      before { allow(client).to receive(:handle_json_message) }

      it 'passes the data to handle_json_message' do
        client.__send__(:handle_message, data)
        expect(client).to have_received(:handle_json_message).with(data)
      end
    end

    context 'when the encoding is etf' do
      let(:client) { described_class.new(url: url, token: token, encoding: :etf) }

      before do
        allow(client).to receive(:handle_etf_message)
        client.instance_variable_set(:@encoding, :etf)
      end

      it 'passes the data to handle_etf_message' do
        client.__send__(:handle_message, data)
        expect(client).to have_received(:handle_etf_message).with(data)
      end
    end
  end

  describe '#handle_json_message' do
    let(:json) { instance_double('String', 'json') }
    let(:op_code) { Vox::Gateway::Client::OPCODES[:HELLO] }
    let(:op) { Vox::Gateway::Client::OPCODES[op_code] }
    let(:data) do
      { s: instance_double('Integer', 'seq'), op: op_code }
    end

    before do
      allow(client).to receive(:emit)
      allow(MultiJson).to receive(:load).with(json, symbolize_keys: true).and_return data
    end

    it 'emits an event based on the opcode' do
      client.__send__(:handle_json_message, json)
      expect(client).to have_received(:emit).with(op, data)
    end
  end

  describe '#handle_etf_message' do
    let(:etf) { instance_double('String', 'etf') }
    let(:op_code) { Vox::Gateway::Client::OPCODES[:HELLO] }
    let(:op) { Vox::Gateway::Client::OPCODES[op_code] }
    let(:data) do
      { s: instance_double('Integer', 'seq'), op: op_code }
    end

    before do
      allow(client).to receive(:emit)
      allow(Vox::ETF).to receive(:decode).with(etf).and_return(data)
    end

    it 'emits an event based on the opcode' do
      client.__send__(:handle_etf_message, etf)
      expect(client).to have_received(:emit).with(op, data)
    end
  end

  describe '#handle_dispatch' do
    let(:type) { instance_double('String', 'type') }
    let(:data) { instance_double('Hash', 'data') }
    let(:payload) { { t: type, d: data } }

    before { allow(client).to receive(:emit) }

    it 'checks the type key to determine the event that should be raised' do
      client.__send__(:handle_dispatch, payload)
      expect(client).to have_received(:emit).with(type, data)
    end
  end

  describe '#handle_hello' do
    let(:hb_interval) { 1000 }
    let(:payload) do
      { d: { heartbeat_interval: hb_interval } }
    end
    let(:thread) { instance_double('Thread') }

    before do
      allow(Thread).to receive(:new).and_yield.and_return(thread)
      allow(client).to receive(:send_resume)
      allow(client).to receive(:send_identify)
      allow(client).to receive(:heartbeat_loop)
    end

    it 'sets the heartbeat interval' do
      client.__send__(:handle_hello, payload)
      expect(client.instance_variable_get(:@heartbeat_interval)).to eq(hb_interval / 1000)
    end

    it 'creates a heartbeat loop' do
      client.__send__(:handle_hello, payload)
      expect(client).to have_received(:heartbeat_loop)
    end

    context 'when the session has a sequence number' do
      let(:session) { instance_double('Vox::Gateway::Client::Session', seq: 1) }

      before { client.instance_variable_set(:@session, session) }

      it 'sends a resume packet' do
        client.__send__(:handle_hello, payload)
        expect(client).to have_received(:send_resume)
      end
    end

    context 'when there is no existing session' do
      it 'sends an identify packet' do
        client.__send__(:handle_hello, payload)
        expect(client).to have_received(:send_identify)
      end
    end
  end

  describe '#handle_heartbeat' do
    let(:seq) { instance_double('Integer', 'seq') }
    let(:opcode) { Vox::Gateway::Client::OPCODES[:HEARTBEAT] }
    let(:session) { instance_double('Vox::Gateway::Client::Session', seq: seq) }

    before do
      client.instance_variable_set(:@session, session)
      allow(client).to receive(:send_packet)
    end

    it 'sends a heartbeat packet in response' do
      client.__send__(:handle_heartbeat, nil)
      expect(client).to have_received(:send_packet).with(opcode, seq)
    end
  end

  describe '#handle_ready' do
    let(:session) { instance_double('Vox::Gateway::Client::Session') }
    let(:session_id) { instance_double('String', 'session_id') }
    let(:payload) do
      { session_id: session_id }
    end

    before do
      allow(session).to receive(:id=)
      client.instance_variable_set(:@session, session)
    end

    it 'sets the session id' do
      client.__send__(:handle_ready, payload)
      expect(session).to have_received(:id=).with(session_id)
    end
  end

  describe '#handle_invalid_session' do
    let(:session) { instance_double('Vox::Gateway::Client::Session') }

    before do
      allow(session).to receive(:seq=)
      client.instance_variable_set(:@session, session)
      allow(client).to receive(:send_identify)
    end

    it 'resets the sequence number of the session' do
      client.__send__(:handle_invalid_session, nil)
      expect(session).to have_received(:seq=).with(nil)
    end

    it 'sends identify' do
      client.__send__(:handle_invalid_session, nil)
      expect(client).to have_received(:send_identify)
    end
  end

  describe '#handle_reconnect' do
    before do
      allow(ws).to receive(:close)
      client.instance_variable_set(:@websocket, ws)
    end

    it 'closes the websocket with code 4000' do
      client.__send__(:handle_reconnect, nil)
      expect(ws).to have_received(:close).with(anything, 4000)
    end
  end

  describe '#handle_heartbeat_ack' do
    it 'sets the heartheat ack indicator to true' do
      client.__send__(:handle_heartbeat_ack, nil)
      expect(client.instance_variable_get(:@heartbeat_acked)).to be true
    end
  end

  describe '#handle_close' do
    let(:reason) { instance_double('String', 'reason') }
    let(:unrecoverable_codes) { [4003, 4004, 4011] }
    let(:recoverable_codes) { Array(4000..4014) - unrecoverable_codes }

    before { allow(client).to receive(:connect) }

    context 'when the close code is recoverable' do
      let(:codes) { recoverable_codes }

      it 'attempt to reconnect' do
        codes.each do |code|
          client.__send__(:handle_close, { code: code, reason: reason })
          expect(client.instance_variable_get(:@should_reconnect).pop).to eq true
        end
      end
    end

    context 'when the close code is not recoverable' do
      let(:codes) { unrecoverable_codes }

      it 'does not attempt to reconnect' do
        codes.each do |code|
          client.__send__(:handle_close, { code: code, reason: reason })
          expect(client.instance_variable_get(:@should_reconnect).pop).to eq false
        end
      end
    end
  end
end
