# frozen_string_literal: true

require 'mime/types'

module Vox
  module HTTP
    # @!visibility private
    module Util
      # Remove members from a hash that have `:undef` as values
      # @example
      #   hash = { foo: 1, bar: :undef, baz: 2 }
      #   filter_hash(hash)
      #   # => { foo: 1, baz: 2 }
      # @param hash [Hash] The hash to filter `:undef` members from.
      # @return [Hash] The given hash with all members with an `:undef` value removed.
      # @!visibility private
      def filter_undef(hash)
        hash.reject { |_, v| v == :undef }
      end

      # Get the MIME type from a File object or path for UploadIO purposes
      # @!visibility private
      # @param file [File, String] File object or String for a file path.
      # @return [String] Returns the MIME type for a file if any. Defaults to application/octet-stream
      def mime_for_file(file)
        path = file.is_a?(File) ? file.path : file
        MIME::Types.type_for(path)[0] || 'application/octet-stream'
      end
    end
  end
end
