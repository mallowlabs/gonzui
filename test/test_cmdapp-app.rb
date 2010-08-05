#! /usr/bin/env ruby
require File.dirname(__FILE__) + '/test_helper.rb'
require 'gonzui/cmdapp'
require '_test-util'

class CommandLineApplicationTest < Test::Unit::TestCase
  class TestApplication < Gonzui::CommandLineApplication
    def parse_options
      option_table = []
      return parse_options_to_hash(option_table)
    end

    def start
      parse_options
      return @config
    end
  end


  def test_app
    app = TestApplication.new
    config = app.start
    assert(config.is_a?(Gonzui::Config))

    original_stdout = STDOUT.dup
    assert(STDOUT.tty?)
    app.be_quiet
	begin
      assert_equal(false, STDOUT.tty?)
	ensure
      STDOUT.reopen(original_stdout)
	end
    assert(STDOUT.tty?)
  end
end
