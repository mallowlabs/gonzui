#! /usr/bin/env ruby
require File.dirname(__FILE__) + '/test_helper.rb'
require '_test-util'

class IndexerTest < Test::Unit::TestCase
  include TestUtil

  def setup
	  @dbm = nil
    @config   = Gonzui::Config.new
  end
  def teardown
    unless @dbm.nil?
      @dbm.close rescue nil
    end
    @dbm = nil
    remove_db(@config)
  end

  def test_index
    remove_db(@config)
    dbm = Gonzui::DBM.open(@config)
    @dbm = dbm
    path = File.join(File.dirname(__FILE__), "foo", "foo.c")
    url = URI.from_path(File.expand_path(path))
    content = Gonzui::Content.new(File.read(path), File.mtime(path))
    source_url = URI.parse("file:///foo")
    indexer = Gonzui::Indexer.new(@config, dbm, source_url, path, content)
    indexer.index
    dbm.flush_cache
    assert_equal(1, dbm.get_ncontents)
    assert(dbm.has_package?("foo"))
#    assert(dbm.has_package?(File.basename(File.dirname(__FILE__))))
    assert(dbm.has_word?("main"))
    assert(dbm.consistent?)
  end
end
