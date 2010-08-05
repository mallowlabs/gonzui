#! /usr/bin/env ruby
require '_load_path.rb'
require 'test/unit'
require 'gonzui'
require '_test-util'

class MonitorTest < Test::Unit::TestCase
  include TestUtil

  def foo
    1
  end

  def test_monitor
    monitor = Gonzui::PerformanceMonitor.new
    assert(monitor.empty?)
    assert_equal("", monitor.format([MonitorTest, :foo]))
    monitor.profile(self, :foo)
    assert(!monitor.empty?)
    summary = monitor.format([MonitorTest, :foo],
                             [MonitorTest, :foo])
    assert(summary.is_a?(String))
    
  end
end
