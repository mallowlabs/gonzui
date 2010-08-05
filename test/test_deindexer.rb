#! /usr/bin/env ruby
require '_load_path.rb'
require '_external_tools.rb'
require 'test/unit'
require 'gonzui'
require '_test-util'

class DeindexerTest < Test::Unit::TestCase
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
    config   = Gonzui::Config.new
    remove_db(config)
    make_db(config)
    dbm = Gonzui::DBM.open(config)
    @dbm = dbm

    package_id = dbm.get_package_id(FOO_PACKAGE)
    assert_equal(0, package_id)
    dbm.get_path_ids(package_id).each {|path_id|
      normalized_path = dbm.get_path(path_id)
      deindexer = Gonzui::Deindexer.new(config, dbm, normalized_path)
      deindexer.deindex
    }
    assert(!dbm.has_package?(FOO_PACKAGE))
    assert_equal(0, dbm.get_ncontents)
    assert_equal(0, dbm.get_nwords)
    assert(dbm.consistent?)
    _test_removed_clearly?(dbm)
  end
end if (ARC_)
