# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

# RUBY-980 Improve logging
# This test suite is for checking IMPORTANT conditions that we log rather than
# trying to do this via brittle unit tests

require 'logger'
require 'newrelic_rpm'
require 'fake_collector'
require 'multiverse_helpers'

class LoggingTest < MiniTest::Unit::TestCase

  include MultiverseHelpers

  def setup
    NewRelic::Agent.stubs(:logger).returns(NewRelic::Agent::MemoryLogger.new)
  end

  def test_logs_app_name
    running_agent_writes_to_log(
       {:app_name => "My App"},
       "Application: My App")
  end

  def test_logs_error_with_bad_app_name
    running_agent_writes_to_log(
       {:app_name => false},
        "No application name configured.")
  end

  def test_logs_dispatcher
    dispatcher = "Y U NO SERVER WEBPAGE"

    running_agent_writes_to_log(
      {:dispatcher => dispatcher},
      dispatcher)
  end

  def test_logs_missing_dispatcher
    running_agent_writes_to_log(
      {:dispatcher => ''},
      "No known dispatcher detected")
  end

  def test_logs_raw_sql_warning
    running_agent_writes_to_log(
      {:'transaction_tracer.record_sql' => 'obfuscated'},
      "Agent is configured to send raw SQL to the service") do

      NewRelic::Agent.config.apply_config(:'transaction_tracer.record_sql' => 'raw')
    end

  end

  def test_logs_ssl_warning
    running_agent_writes_to_log(
      {:ssl => true},
      "Agent is configured not to use SSL when communicating with New Relic's servers") do

      NewRelic::Agent.config.apply_config(:ssl => false)
    end
  end

  def test_logs_if_sending_errors_on_change
    running_agent_writes_to_log(
      {:'error_collector.enabled' => false},
      "Errors will be sent") do

      NewRelic::Agent.config.apply_config(:'error_collector.enabled' => true)
    end
  end

  def test_logs_if_not_sending_errors_on_change
    running_agent_writes_to_log(
      {:'error_collector.enabled' => true},
      "Errors will not be sent") do

      NewRelic::Agent.config.apply_config(:'error_collector.enabled' => false)
    end
  end

  def test_logs_transaction_tracing_disabled
    running_agent_writes_to_log(
      {:'transaction_tracer.enabled' => false},
      "Transaction traces will not be sent")
  end

  def test_invalid_license_key
    setup_agent({}) do |collector|
      collector.stub('connect', {}, 401)
    end

    saw?("Visit NewRelic.com to obtain a valid license key")

    teardown_agent
  end

  def test_logs_monitor_mode_disabled
    running_agent_writes_to_log(
      {:monitor_mode => false },
      "Agent configured not to send data in this environment.")
  end

  def test_logs_missing_license_key
    running_agent_writes_to_log(
      { :license_key => false },
      "No license key found in newrelic.yml config.")
  end

  def test_logs_blank_license_key
    running_agent_writes_to_log(
      { :license_key => '' },
      "No license key found in newrelic.yml config.")
  end

  def test_logs_invalid_license_key
    running_agent_writes_to_log(
      { :license_key => 'a' * 30 },
      "Invalid license key: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
  end

  def test_logs_forking_workers
    running_agent_writes_to_log(
      { :dispatcher => :passenger },
      "Connecting workers after forking.")
  end

  # Helpers
  def running_agent_writes_to_log(options, msg, &block)
    run_agent(options, &block)
    saw?(msg)
  end

  def saw?(*expected_messages)
    # This is actually our MemoryLogger, so it has messages to check. Woot!
    logger = NewRelic::Agent.logger

    flattened = logger.messages.flatten
    expected_messages.each do |expected|
      found = flattened.any? {|msg| msg.to_s.include?(expected)}
      logger.messages.each {|msg| puts msg.inspect} if !found
      assert(found, "Didn't see message '#{expected}'")
    end
  end
end
