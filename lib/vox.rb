# frozen_string_literal: true

require 'vox/version'

# Parent module containing all component pieces
module Vox
  # Setup default appenders, log level, and formatting scheme.
  # @param root_level [Symbol] The default logging level for all `Vox` loggers.
  # @param rules [Hash<Class, Symbol>] Custom levels for each desired class.
  # @example
  #   Vox.setup_default_logger(root_level: :warn, Vox::HTTP: :info, Vox::Gateway: :info)
  def self.setup_default_logger(root_level: :info, **rules)
    Logging.logger[Vox].level = root_level

    rules.each do |log, level|
      Logging.logger[log].level = level
    end

    Logging.color_scheme('vox_default',
                         levels: {
                           debug: :magenta,
                           info: :green,
                           warn: :yellow,
                           error: :red,
                           fatal: %i[white on_red]
                         },
                         date: :blue,
                         logger: :cyan)

    Logging.logger[Vox].add_appenders(
      Logging.appenders.stdout(layout: Logging.layouts.pattern(color_scheme: 'vox_default'))
    )
  end
  # Catch all error for all Vox error subclasses
  class Error < StandardError; end
  # Your code goes here...
end
