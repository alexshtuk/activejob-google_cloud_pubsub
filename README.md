# ActiveJob::GoogleCloudPubsub

[![Build Status](https://travis-ci.org/ursm/activejob-google_cloud_pubsub.svg?branch=master)](https://travis-ci.org/ursm/activejob-google_cloud_pubsub)
[![Gem Version](https://badge.fury.io/rb/activejob-google_cloud_pubsub.svg)](https://badge.fury.io/rb/activejob-google_cloud_pubsub)

Google Cloud Pub/Sub adapter and worker for ActiveJob

## Installation

```ruby
gem 'activejob-google_cloud_pubsub'
```

## Usage

First, change the ActiveJob backend.

``` ruby
Rails.application.config.active_job.queue_adapter = :google_cloud_pubsub
```

Write the Job class and code to use it.

``` ruby
class HelloJob < ApplicationJob
  def perform(name)
    puts "hello, #{name}!"
  end
end
```

``` ruby
class HelloController < ApplicationController
  def say
    HelloJob.perform_later params[:name]
  end
end
```

In order to test the worker in your local environment, it is a good idea to use the Pub/Sub emulator provided by `gcloud` command. Refer to [this document](https://cloud.google.com/pubsub/docs/emulator) for the installation procedure.

When the installation is completed, execute the following command to start up the worker.

``` sh
$ gcloud beta emulators pubsub start

(Switch to another terminal)

$ eval `gcloud beta emulators pubsub env-init`
$ cd path/to/your-app
$ bundle exec activejob-google_cloud_pubsub-worker --project_id=dummy
```

If you hit the previous action, the job will be executed.
(Both the emulator and the worker stop with <kbd>Ctrl+C</kbd>)

## Configuration

### Adapter

When passing options to the adapter, you need to create the object instead of a symbol.

``` ruby
Rails.application.config.active_job.queue_adapter = ActiveJob::GoogleCloudPubsub::Adapter.new(
  async:  false,
  logger: Rails.logger,

  pubsub: Google::Cloud::Pubsub.new(
    project_id:  'MY-PROJECT-ID',
    credentials: 'path/to/keyfile.json'
  )
)
```

#### `async`

Whether to publish messages asynchronously.

Default: `true`

#### `logger`

The logger that outputs a message publishing error. Specify `nil` to disable logging.

Default: `Logger.new($stdout)`

#### `pubsub`

The instance of `Google::Cloud::Pubsub::Project`. Please see [`Google::Cloud::Pubsub.new`](http://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-pubsub/master/google/cloud/pubsub?method=new-class) for details.

Default: `Google::Cloud::Pubsub.new`

### Worker

The following command line flags can be specified. All flags are optional.

#### `--require=PATH`

The path of the file to load before the worker starts up.

Default: `./config/environment`

#### `--queue=NAME`

The name of the queue the worker handles.

Note: One worker can handle only one queue. If you use multiple queues, you need to launch multiple worker processes.

Default: `default`

#### `--min_threads=N`

Minimum number of worker threads.

Default: `0`

#### `--max_threads=N`

Maximum number of worker threads.

Default: number of logical cores

#### `--project_id=PROJECT_ID`, `--credentials=KEYFILE_PATH`

Credentials of Google Cloud Platform. Please see [the document](https://github.com/GoogleCloudPlatform/google-cloud-ruby/blob/master/AUTHENTICATION.md) for details.

### Configuration

Put this to your config/activejob_gc_pubsub.rb

``` ruby
ActiveJob::GoogleCloudPubsub.configure do |config|
  # Formatter to use to decorate jobs queue name
  # use, when you want more than one rails project or multiple environgments to connect to the same GCP project
  config.queue_name_formatter = ->(queue_name) { "#{Rails.env}__#{project}__#{queue_name}" }

  # Logger to use  
  config.logger = Rails.logger

  # Params to use for Google PubSub client initialization
  config.pubsub_params = { project_id: 'MY-PROJECT-ID', credentials: 'path/to/keyfile.json' }
end
```

Configuration is respected by both Adapter and Worker

### before_publish and before_process callbacks

Library supports callbacks which are executed before job is published to queue by the adapter and before job is processed by the worker
 
This is an analogue of Sidekiq's Middlewares. 

Helps solve, par example the problem of passing correlation ID for background jobs, so you can always tell which job was created by wich request

Usage example (put this in config/initializers/activejob_gc_pubsub.rb):

``` ruby
ActiveJob::GoogleCloudPubsub.configure do |config|
  config.before_publish_callbacks << ->(job) { job['__request_id'] = RequestHeadersMiddleware.store['X-Request-Id'.to_sym] } }
end

ActiveJob::GoogleCloudPubsub.configure do |config|
  config.before_process_callbacks <<
    ->(job) { RequestHeadersMiddleware.store['X-Request-Id'.to_sym] = job['__request_id'] || SecureRandom.uuid }
end
```

(example relies on [RequestHeadersMiddleware](https://github.com/fidor/request_headers_middleware) - nice way to introduce correlation id to the system) 

## Development

``` sh
$ bundle exec rake spec
```

## Contributing

Bug reports and pull requests are welcome.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
