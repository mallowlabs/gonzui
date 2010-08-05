#! /usr/bin/env ruby
require '_load_path.rb'
require 'test/unit'
require 'gonzui'
require '_test-util'

class IndexerTest < Test::Unit::TestCase
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

  def test_index
    config   = Gonzui::Config.new
    remove_db(config)
    dbm = Gonzui::DBM.open(config)
    @dbm = dbm
    path = "foo/foo.c"
    url = URI.from_path(File.expand_path(path))
    content = Gonzui::Content.new(File.read(path), File.mtime(path))
    source_url = URI.parse("file:///foo")
    indexer = Gonzui::Indexer.new(config, dbm, source_url, path, content)
    indexer.index
    dbm.flush_cache
    assert_equal(1, dbm.get_ncontents)
    assert(dbm.has_package?("foo"))
    assert(dbm.has_word?("main"))
    assert(dbm.consistent?)
  end
end
