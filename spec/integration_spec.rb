require 'spec_helper'

require 'json'
require 'thread'
require 'timeout'

RSpec.describe ActiveJob::GoogleCloudPubsub, :use_pubsub_emulator do
  class GreetingJob < ActiveJob::Base
    def perform(name)
      $queue.push "hello, #{name}!"
    end
  end

  around :all do |example|
    orig, ActiveJob::Base.logger = ActiveJob::Base.logger, nil

    begin
      example.run
    ensure
      ActiveJob::Base.logger = orig
    end
  end

  before :each do |example|
    $queue = Thread::Queue.new
  end

  context do
    around :each do |example|
      run_worker(&example)
    end

    example 'it executes jobs' do
      GreetingJob.perform_later 'alice'
      GreetingJob.set(wait: 0.1).perform_later 'bob'
      GreetingJob.set(wait_until: Time.now + 0.2).perform_later 'charlie'

      Timeout.timeout 3 do
        expect(3.times.map { $queue.pop }).to contain_exactly(
                                                  'hello, alice!',
                                                  'hello, bob!',
                                                  'hello, charlie!'
                                              )
      end
    end

    context 'with before_publish callbacks in adapter' do
      before(:all) do
        @original_callbacks = [*ActiveJob::GoogleCloudPubsub.before_publish_callbacks]

        ActiveJob::GoogleCloudPubsub.before_publish_callbacks << ->(job) { job.arguments = job.arguments.map { |name| "Mrs. #{name}" } }
      end

      after(:all) do
        ActiveJob::GoogleCloudPubsub.before_publish_callbacks.clear
        ActiveJob::GoogleCloudPubsub.before_publish_callbacks.concat(@original_callbacks)
      end

      it 'respects callback' do
        GreetingJob.perform_later 'Alice'

        Timeout.timeout 3 do
          expect($queue.pop).to eq('hello, Mrs. Alice!')
        end
      end
    end

    context 'with before_process callbacks in worker' do
      before(:all) do
        @original_callbacks = [*ActiveJob::GoogleCloudPubsub.before_process_callbacks]

        ActiveJob::GoogleCloudPubsub.before_process_callbacks << ->(job) { job['arguments'] = job['arguments'].map { |name| "Mrs. #{name}" } }
      end

      after(:all) do
        ActiveJob::GoogleCloudPubsub.before_process_callbacks.clear
        ActiveJob::GoogleCloudPubsub.before_process_callbacks.concat(@original_callbacks)
      end

      it 'respects callback' do
        GreetingJob.perform_later 'Alice'

        Timeout.timeout 3 do
          expect($queue.pop).to eq('hello, Mrs. Alice!')
        end
      end
    end

    it 'creates default queues if no formatter provided' do
      expect(@pubsub).to receive(:topic).with('activejob-queue-default').and_call_original

      GreetingJob.perform_later 'Alice'

      Timeout.timeout 3 do
        expect($queue.pop).to eq('hello, Alice!')
      end
    end
  end

  context 'when formatter provided' do
    around :each do |example|
      orig = ActiveJob::GoogleCloudPubsub.queue_name_formatter
      ActiveJob::GoogleCloudPubsub.queue_name_formatter = ->(name) { "formatted_#{name}" }

      begin
        example.run
      ensure
        ActiveJob::GoogleCloudPubsub.queue_name_formatter = orig
      end
    end

    around :each do |example|
      run_worker(&example)
    end

    it 'creates formatted queues' do
      expect(@pubsub).to receive(:topic).with('formatted_activejob-queue-default').and_call_original

      GreetingJob.perform_later 'Alice'

      Timeout.timeout 3 do
        expect($queue.pop).to eq('hello, Alice!')
      end
    end
  end

  context 'with pubsub params in config' do
    around :each do |example|
      orig = ActiveJob::GoogleCloudPubsub.pubsub_params
      ActiveJob::GoogleCloudPubsub.pubsub_params = {emulator_host: @pubsub_emulator_host, project_id: 'activejob-test'}

      begin
        example.run
      ensure
        ActiveJob::GoogleCloudPubsub.pubsub_params = orig
      end
    end

    it 'repects params in adapter' do
      expect(Google::Cloud::Pubsub).to receive(:new).with(project_id: 'activejob-test', emulator_host: @pubsub_emulator_host)
      ActiveJob::GoogleCloudPubsub::Adapter.new.pubsub
    end

    it 'repects params in worker' do
      expect(Google::Cloud::Pubsub).to receive(:new).with(project_id: 'activejob-test', emulator_host: @pubsub_emulator_host)
      ActiveJob::GoogleCloudPubsub::Worker.new.pubsub
    end
  end

  context 'when logger is specified in config' do
    let!(:specific_logger) { Logger.new('logfile.log') }

    around :each do |example|
      orig = ActiveJob::GoogleCloudPubsub.logger
      ActiveJob::GoogleCloudPubsub.logger = specific_logger

      begin
        example.run
      ensure
        ActiveJob::GoogleCloudPubsub.logger = orig
      end
    end

    it 'uses this logger in adapter' do
      expect(ActiveJob::GoogleCloudPubsub::Adapter.new.logger).to be(specific_logger)
    end

    it 'uses this logger  in worker' do
      expect(ActiveJob::GoogleCloudPubsub::Worker.new.logger).to be(specific_logger)
    end
  end

  private

  def run_worker(&block)
    pubsub = Google::Cloud::Pubsub.new(emulator_host: @pubsub_emulator_host, project_id: 'activejob-test')
    worker = ActiveJob::GoogleCloudPubsub::Worker.new(pubsub: pubsub)

    worker.ensure_subscription

    thread = Thread.new {
      worker.run
    }

    thread.abort_on_exception = true

    block.call
  ensure
    thread.kill if thread
  end
end
