# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require File.expand_path(File.join(File.dirname(__FILE__),'..','..','test_helper'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','data_container_tests'))

require 'new_relic/agent/custom_event_aggregator'

module NewRelic::Agent
  class CustomEventAggregatorTest < Minitest::Test
    def setup
      freeze_time
      @aggregator = NewRelic::Agent::CustomEventAggregator.new
    end

    # Helpers for DataContainerTests

    def create_container
      @aggregator
    end

    def populate_container(container, n)
      n.times do |i|
        container.record(:atype, { :number => i })
      end
    end

    include NewRelic::DataContainerTests

    def test_record_without_pre_registration_abides_by_default_limit
      n = CustomEventAggregator::DEFAULT_CAPACITY + 1
      n.times do |i|
        @aggregator.record(:footype, :number => i)
      end

      results = @aggregator.harvest!
      assert_equal(CustomEventAggregator::DEFAULT_CAPACITY, results.size)
    end

    def test_record_with_pre_registration_abides_by_registered_limit
      @aggregator.register_event_type(:type, 10)

      11.times do |i|
        @aggregator.record(:type, :foo => :bar)
      end

      results = @aggregator.harvest!
      assert_equal(10, results.size)
    end

    def test_record_respects_event_limits_by_type
      @aggregator.register_event_type(:a, 10)
      @aggregator.register_event_type(:b, 5)

      11.times do |i|
        @aggregator.record(:a, :foo => :bar)
        @aggregator.record(:b, :foo => :bar)
      end

      events = @aggregator.harvest!

      assert_equal(15, events.size)

      a_events = events.select { |e| e[0]['type'] == 'a' }
      b_events = events.select { |e| e[0]['type'] == 'b' }

      assert_equal(10, a_events.size)
      assert_equal(5,  b_events.size)
    end

    def test_merge_respects_event_limits_by_type
      @aggregator.register_event_type(:a, 10)
      @aggregator.register_event_type(:b, 5)

      11.times do |i|
        @aggregator.record(:a, :foo => :bar)
        @aggregator.record(:b, :foo => :bar)
      end

      old_events = @aggregator.harvest!

      3.times do |i|
        @aggregator.record(:a, :foo => :bar)
        @aggregator.record(:b, :foo => :bar)
      end

      @aggregator.merge!(old_events)

      events = @aggregator.harvest!

      a_events = events.select { |e| e[0]['type'] == 'a' }
      b_events = events.select { |e| e[0]['type'] == 'b' }

      assert_equal(10, a_events.size)
      assert_equal(5,  b_events.size)
    end

    def test_record_adds_type_and_timestamp
      t0 = Time.now
      @aggregator.record(:type_a, :foo => :bar, :baz => :qux)

      events = @aggregator.harvest!

      assert_equal(1, events.size)
      event = events.first

      assert_equal({ 'type' => 'type_a', 'timestamp' => t0.to_i }, event[0])
      assert_equal({ 'foo'  => 'bar'   , 'baz'       => 'qux'   }, event[1])
    end
  end
end