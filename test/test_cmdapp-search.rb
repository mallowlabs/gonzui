#! /usr/bin/env ruby
require File.dirname(__FILE__) + '/test_helper.rb'
require 'gonzui/cmdapp'
require '_external_tools.rb'
require '_test-util'

class CommandLineSearcherTest < Test::Unit::TestCase
  include TestUtil

  include Gonzui::Util

  def search(config, pattern, options = {})
    strio = StringIO.new
    options['out'] = strio
    searcher = Gonzui::CommandLineSearcher.new(config, options)
    searcher.search(pattern)
    begin
      if options['context']
        return strio.string.gsub(/^== .*\n/s, "")
      else
        return strio.string
      end
    ensure
      searcher.finish
    end
  end

  def grep(argument)
    ENV['GREP_OPTIONS'] = ""
    files = FOO_FILES.map {|basename| File.join(FOO_PACKAGE, basename) }
	  cd = "cd"
	  cd << " /d" if (/mswin|mingw|bccwin/ =~ RUBY_PLATFORM)
    tmp = IO.popen("#{cd} #{@@foo} && grep #{argument} #{files.join(' ')}").read
    return tmp.gsub(/\t/, " " * 8)
  end

  def grep_has_color_option?
    status = system("grep --help | grep -q color")
    return status
  end

  def test_result
    require_command('grep')
    config   = Gonzui::Config.new
    make_db(config)
    make_dist_tree

    by_gonzui = search(config, "foo")
    by_grep   = grep("-H 'foo'")
    assert_equal(by_grep.split.join, by_gonzui.split.join)

    by_gonzui = search(config, "foo", "package" => FOO_PACKAGE)
    by_grep   = grep("-H 'foo'")
    assert_equal(by_grep.split.join, by_gonzui.split.join)

    by_gonzui = search(config, "foo", "package" => "hoge")
    by_grep   = ""
    assert_equal(by_grep.split.join, by_gonzui.split.join)

    by_gonzui = search(config, "foo", "type" => "fundef")
    by_grep   = grep(%Q;-H "^foo (";)
    assert_equal(by_grep.split.join, by_gonzui.split.join)

    by_gonzui = search(config, "foo", "line-number" => true)
    by_grep   = grep("-nH 'foo'")
    assert_equal(by_grep.split.join, by_gonzui.split.join)

    by_gonzui = search(config, "foo", "no-filename" => true)
    by_grep   = grep("-h 'foo'")
    assert_equal(by_grep.split.join, by_gonzui.split.join)

    by_gonzui = search(config, "mai", "prefix" => true)
    by_grep   = grep("-H 'mai'")
    assert_equal(by_grep.split.join, by_gonzui.split.join)

    by_gonzui = search(config, "f.o", "regexp" => true)
    by_grep   = grep("-H 'f.o'")
    assert_equal(by_grep.split.join, by_gonzui.split.join)

    by_gonzui = search(config, "foo", "type" => "funcall")
    by_grep   = grep("-H ' foo(1, 2)'")
    assert_equal(by_grep.split.join, by_gonzui.split.join)

    (1..10).each {|i|
      by_gonzui = search(config, "foo", "type" => "fundef",
                         "context" => i)
      by_grep   = grep(%Q;-hC#{i} "^foo (";)
      assert_equal(by_grep.split.join, by_gonzui.split.join)
    }

    if grep_has_color_option?
      by_gonzui = search(config, "main",
                         "line-number" => true, "color" => true)
      ENV["GREP_COLOR"] = ""
      by_grep   = grep("-nH --color=always 'main'")
      assert_equal(by_grep.split.join, by_gonzui.split.join)
    end
  end
end if (GREP_ && ARC_)
