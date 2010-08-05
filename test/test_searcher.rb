#! /usr/bin/env ruby
require '_load_path.rb'
require '_external_tools.rb'
require 'test/unit'
require 'gonzui'
require '_test-util'

class SearcherTest < Test::Unit::TestCase
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

  def test_searcher
    config = Gonzui::Config.new
    make_db(config)
    dbm = Gonzui::DBM.open(config)
    @dbm = dbm
    search_query = Gonzui::SearchQuery.new(config, "foo")
    searcher = Gonzui::Searcher.new(dbm, search_query, 100)
    result = searcher.search
    assert(result.is_a?(Gonzui::SearchResult))
    assert(result.length > 0)

    search_query = Gonzui::SearchQuery.new(config, "205438967we9tn8we09asf")
    searcher = Gonzui::Searcher.new(dbm, search_query, 100)
    result = searcher.search
    assert_equal(0, result.length)

    dbm.close
  end
end if (ARC_)
