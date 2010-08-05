#! /usr/bin/env ruby
require File.dirname(__FILE__) + '/test_helper.rb'
require '_external_tools.rb'
require '_test-util'

class DeindexerTest < Test::Unit::TestCase
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

  def _test_removed_clearly?(dbm)
    exclude_dbs = [
      :seq, :stat, :type_typeid, :typeid_type, :version,
    ]
    dbm.each_db_name {|db_name|
      next if exclude_dbs.include?(db_name.intern)
      assert(dbm.send(db_name).empty?)
    }
  end

  def test_deindex
    remove_db(@config)
    make_db(@config)
    dbm = Gonzui::DBM.open(@config)
    @dbm = dbm

    package_id = dbm.get_package_id(FOO_PACKAGE)
    assert_equal(0, package_id)
    dbm.get_path_ids(package_id).each {|path_id|
      normalized_path = dbm.get_path(path_id)
      deindexer = Gonzui::Deindexer.new(@config, dbm, normalized_path)
      deindexer.deindex
    }
    assert(!dbm.has_package?(FOO_PACKAGE))
    assert_equal(0, dbm.get_ncontents)
    assert_equal(0, dbm.get_nwords)
    assert(dbm.consistent?)
    _test_removed_clearly?(dbm)
  end
end if (ARC_)
