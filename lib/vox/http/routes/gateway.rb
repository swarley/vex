# frozen_string_literal: true

require 'vox/http/route'

module Vox
  module HTTP
    module Routes
      # Mixin for gateway routes, used for retriving information
      # about connecting to the gateway.
      module Gateway
        # rubocop:disable Naming/AccessorMethodName

        # Fetch the URL to use for a gateway connection.
        # @return [Hash<:url, String>] An object with one key `url` that maps to the URL
        #   for connecting to the gateway.
        # @vox.api_docs https://discord.com/developers/docs/topics/gateway#get-gateway
        def get_gateway
          request(Route.new(:GET, '/gateway'))
        end

        # Fetch the URL to use for a gateway connection, with additional sharding information.
        # @return [Hash{ :url => String, :shards => Integer, :session_start_limit => Hash<Symbol, Integer>}]
        #   An object that includes the URL to connect to the gateway with, the recommended number of shards,
        #   as well as a [session start limit](https://discord.com/developers/docs/topics/gateway#session-start-limit-object-session-start-limit-structure)
        #   object.
        # @vox.api_docs https://discord.com/developers/docs/topics/gateway#get-gateway-bot
        def get_gateway_bot
          request(Route.new(:GET, '/gateway/bot'))
        end

        # rubocop:enable Naming/AccessorMethodName
      end
    end
  end
end
