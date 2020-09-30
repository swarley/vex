# frozen_string_literal: true

require 'faraday'
require 'logging'
require 'securerandom'
require 'vox'
require 'vox/http/route'
require 'vox/http/routes'
require 'vox/http/error'
require 'vox/http/middleware'

module Vox
  # The HTTP component used to interact with the REST portion of the API.
  # Contains a client, as well as modular paths if you wish to provide your own client
  # with support for the same `request` method signature.
  module HTTP
    # HTTP Client for interacting with the REST portion of the Discord API
    class Client
      # include AuditLog
      # include Channel
      # include Emoji
      # include Guild
      # include Invite
      # include User
      # include Voice
      # include Webhook
      include Routes

      # @!visibility private
      attr_reader :conn

      # TODO: Maybe fallback to extrapolating the key from URLs so we
      # can expose the connection for use outside of our request function?

      # Discord REST API version.
      API_VERSION = '8'

      # Base URL to base endpoints off of.
      API_BASE = "https://discord.com/api/v#{API_VERSION}/"

      # Headers that form the base for every request.
      DEFAULT_HEADERS = {
        'User-Agent': "DiscordBot (https://github.com/swarley/vox, #{Vox::VERSION})"
      }.freeze

      # @note The use of the positional token is deprecated and will be removed.
      def initialize(depr_token = nil, token: nil, token_type: 'Bot')
        token ||= depr_token
        @conn = default_connection
        @conn.authorization(token_type, token.delete_prefix("#{token_type} "))
        yield(@conn) if block_given?
      end

      # Run a request
      # @param query [Hash<String, String>, nil] Query string parameters.
      # @param data [Hash<(String, Integer), (String, #content_type)>, String, nil] HTTP body for non-JSON payloads.
      # @param json [Hash, nil] Object that will be serialized to JSON for requests.
      # @param raw [true, false] Whether or not the response body should be parsed from
      #   JSON.
      # @param reason [String, nil] Reason for use in paths that support audit log reasons.
      # @return [Hash, nil] The response body serialized to a Hash, or nil when a route returns 204.
      def request(route, query: nil, data: nil, json: nil, raw: nil, reason: nil)
        req = @conn.build_request(route.verb) do |r|
          setup_basic_request(r, route, query: query, reason: reason)

          if json
            r.body = MultiJson.dump(json)
            r.headers['Content-Type'] = 'application/json'
          elsif data
            r.body = data
          end
        end

        begin
          resp = @conn.builder.build_response(@conn, req)
          handle_response(resp, raw, req.options.context[:trace])
        rescue Error::TooManyRequests
          retry
        end
      end

      # @!visibility private
      # Hide the big instance variables
      def inspect
        "#<Vox::HTTP::Client:0x#{object_id.to_s(16).rjust(16, '0')}>"
      end

      private

      # @param req [Faraday::Request] Request to be executed
      # @param route [Vox::HTTP::Route]
      # @param query [Hash<String, String>, nil]
      # @param reason [String, nil]
      def setup_basic_request(req, route, query: nil, reason: nil)
        req.path = route.format.delete_prefix('/')
        req.params = query unless query.nil? || query.empty?
        req.headers['X-Audit-Log-Reason'] = reason if reason
        req.options.context = { rl_key: route.rl_key, trace: SecureRandom.alphanumeric(6) }
      end

      # @param resp [Faraday::Response] The response to be processed.
      def handle_response(resp, raw, req_id)
        raise Error::ServerError.new(req_id) if (500..600).cover? resp.status

        return nil if resp.status == 204 || resp.status == 304

        data = raw ? resp.body : MultiJson.load(resp.body, symbolize_keys: true)
        case resp.status
        when 200..300
          data
        when 400
          raise Error::BadRequest.new(data, req_id)
        when 401
          raise Error::Unauthorized.new(data, req_id)
        when 403
          raise Error::Forbidden.new(data, req_id)
        when 404
          raise Error::NotFound.new(data, req_id)
        when 405
          raise Error::MethodNotAllowed.new(data, req_id)
        when 429
          raise Error::TooManyRequests.new(data, req_id)
        end
      end

      # A default connection used when you're not passing your own
      # @return [Faraday::Connection]
      def default_connection
        Faraday.new(url: API_BASE, headers: DEFAULT_HEADERS) do |faraday|
          faraday.use :vox_ratelimiter
          faraday.request :multipart
          faraday.response(
            :logger,
            Logging.logger['Vox::HTTP'],
            { formatter: Vox::HTTP::Middleware::LogFormatter }
          )
        end
      end
    end
  end
end
