# frozen_string_literal: true

require 'vox/http/routes/audit_log'
require 'vox/http/routes/channel'
require 'vox/http/routes/emoji'
require 'vox/http/routes/guild'
require 'vox/http/routes/gateway'
require 'vox/http/routes/invite'
require 'vox/http/routes/user'
require 'vox/http/routes/voice'
require 'vox/http/routes/webhook'

module Vox
  module HTTP
    # Module that contains all route containers.
    module Routes
      # Include all route containers if this module is included
      def self.included(klass)
        constants.each { |m| klass.include const_get(m) }
      end
    end
  end
end
