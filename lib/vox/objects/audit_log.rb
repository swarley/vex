# frozen_string_literal: true

require 'vox/objects/api_object'

module Vox
  class AuditLog < APIObject
    class Entry < APIObject
      # Optional audit log information.
      class Options < APIObject
        # @!attribute [r] delete_member_days
        #   @return [String]
        attr_reader :delete_member_days

        # @!attribute [r] members_removed
        #   @return [String]

        # @!attribute [r] channel_id
        #   @return [String]
        attr_reader :channel_id

        # @!attribute [r] message_id
        #   @return [String]
        attr_reader :message_id

        # @!attribute [r] count
        #   @return [String]
        attr_reader :count

        # @!attribute [r] id
        #   @return [String]
        attr_reader :id

        # @!attribute [r] type
        #   @return [String]
        attr_reader :type

        # @!attribute [r] role_name
        #   @return [String]
        attr_reader :role_name

        def update_data(data)
          data[:channel_id] = data[:channel_id]&.to_s
          data[:message_id] = data[:message_id]&.to_s
          data[:id] = data[:id]&.to_s

          super
        end
      end

      # A change within the audit log.
      class Change
        # @!attribute [r] new_value
        #   @return [Object, nil]
        attr_reader :new_value

        # @!attribute [r] old_value
        #   @return [Object, nil]
        attr_reader :old_value

        # @!attribute [r] key
        #   @return [String]
        attr_reader :key

        def initialize(data)
          @new_value = data[:new_value]
          @old_value = data[:old_value]
          @key = data[:key]
        end
      end

      # @!attribute [r] target_id
      #   @return [String]
      attr_reader :target_id

      # @!attribute [r] changes
      #   @return [Array<Change>]
      attr_reader :changes

      # @!attribute [r] id
      #   @return [String]
      attr_reader :id

      # @!attribute [r] action_type
      #   @return [Integer]
      attr_reader :action_type

      # @!attribute [r] options
      #   @return [Options, nil]
      attr_reader :options

      # @!attribute [r] reason
      #   @return [String, nil]
      attr_reader :reason

      def update_data(data)
        data[:target_id] = data[:target_id]&.to_s
        data[:changes] = data[:changes].collect { |c| Change.new(c) } if data[:changes]
        data[:user_id] = data[:user_id]&.to_s
        data[:id] = data[:id]&.id
        data[:options] = Options.new(data[:options]) if data[:options]

        super
      end
    end
  end
end
