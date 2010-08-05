#! /usr/bin/env ruby
require File.dirname(__FILE__) + '/test_helper.rb'
require '_external_tools.rb'
require 'gonzui/webapp'
require '_test-util'

class TextBeautifierTest < Test::Unit::TestCase
  include TestUtil

  def setup
	@dbm = nil
  end
  def teardown
    unless @dbm.nil?
      @dbm.close rescue nil
    end
    @dbm = nil
  end

  def init_dbm(config)
    remove_db(config)
    make_archives
    add_package(config)
    dbm = Gonzui::DBM.open(config)
    @dbm = dbm
    return dbm
  end

  def test_beautify
    config = Gonzui::Config.new
    dbm = init_dbm(config)
    path_id = dbm.get_path_id("foo-0.1/foo.c")
    assert(path_id.is_a?(Fixnum))
    content = dbm.get_content(path_id)
    digest  = dbm.get_digest(path_id)
    beautifier = Gonzui::TextBeautifier.new(content, digest, [], "search?q=")
    html = beautifier.beautify
    assert(html.is_a?(Array))
    assert(html.flatten.include?(:span))
    remove_db(config)
  end
end if (ARC_)
