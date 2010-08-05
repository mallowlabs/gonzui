#! /usr/bin/env ruby
require File.dirname(__FILE__) + '/test_helper.rb'
require '_test-util'
require 'time'

class LoggerTest < Test::Unit::TestCase
  def create_test_case
    format = "foo %s"
    arguments = ["bar"]
    message = sprintf(format, arguments)
    return format, arguments, message
  end

  def test_log
    format, arguments, message = create_test_case

    strio = StringIO.new
    logger = Gonzui::Logger.new(strio)
    a = Time.now
    logger.log(format, *arguments)

    log = strio.string
    m = /^(.*?) (.*)/.match(log)
    assert(m.is_a?(MatchData))
    assert_equal(message, m[2])

    time = Time.parse(m[1])
    assert(time.is_a?(Time))
    assert((time - a).abs < 1) # within 1 sec
  end

  def test_vlog
    format, arguments, message = create_test_case

    strio = StringIO.new
    logger = Gonzui::Logger.new(strio, false)
    logger.vlog(format, arguments)
    assert(strio.string.empty?)

    logger = Gonzui::Logger.new(strio, true)
    logger.vlog(format, arguments)
    assert(/^.*? #{message}/.match(strio.string))
  end

  def test_monitor
    format, arguments, message = create_test_case
    strio1 = StringIO.new
    strio2 = StringIO.new
    logger = Gonzui::Logger.new(strio1)
    logger.log(format, arguments)
    assert_equal(false, strio1.string.empty?)
    assert(strio2.string.empty?)

    logger.monitor = strio2
    logger.log(format, arguments)
    assert_equal(false, strio2.string.empty?)
    assert(strio1.string.length > strio2.string.length)
  end
end

