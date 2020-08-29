# frozen_string_literal: true

require 'rspec'
require 'vox/http/routes/gateway'

RSpec.describe Vox::HTTP::Routes::Gateway do
  let(:client) { Class.new { include Vox::HTTP::Routes::Gateway }.new }

  before do
    stub_const('Route', Vox::HTTP::Route)
    allow(client).to receive(:request).with(any_args)
  end

  describe '#get_gateway' do
    it 'sends a request with no parameters' do
      client.get_gateway
      route = Route.new(:GET, '/gateway')
      expect(client).to have_received(:request).with(route)
    end
  end

  describe '#get_gateway_bot' do
    it 'sends a request with no parameters' do
      client.get_gateway_bot
      route = Route.new(:GET, '/gateway/bot')
      expect(client).to have_received(:request).with(route)
    end
  end
end
