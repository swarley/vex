# frozen_string_literal: true

require 'vox/http/client'
require 'vox/gateway/client'

Vox.setup_default_logger

token = ENV['VOX_TOKEN']
rest = Vox::HTTP::Client.new(token)
gateway = Vox::Gateway::Client.new(url: rest.get_gateway[:url], token: token)

gateway.on(:MESSAGE_CREATE) do |data|
  rest.create_message(data[:channel_id], content: 'pong') if data[:content] == 'vox.ping'
end

Signal.trap('INT') { gateway.close('Disconnecting') }

gateway.connect
