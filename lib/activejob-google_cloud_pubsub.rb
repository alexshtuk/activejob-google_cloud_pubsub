module ActiveJob
  module GoogleCloudPubsub
    autoload :Adapter, 'activejob-google_cloud_pubsub/adapter'
    autoload :VERSION, 'activejob-google_cloud_pubsub/version'
    autoload :Worker,  'activejob-google_cloud_pubsub/worker'

    class << self
      def configure
        yield self
      end

      attr_accessor :queue_name_formatter
      attr_accessor :pubsub_params
      attr_accessor :logger

      def before_publish_callbacks
        @before_publish_callbacks ||= []
      end

      def before_process_callbacks
        @before_process_callbacks ||= []
      end
    end
  end
end

require 'active_job'
require 'google/cloud/pubsub'

ActiveJob::QueueAdapters.autoload :GoogleCloudPubsubAdapter, 'activejob-google_cloud_pubsub/adapter'
