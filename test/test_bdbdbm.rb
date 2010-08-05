#! /usr/bin/env ruby
require File.dirname(__FILE__) + '/test_helper.rb'
require '_test-util'

class BDBDBMTest < Test::Unit::TestCase
  include TestUtil

  def setup
	@dbm = nil
  end
  def teardown
    unless @dbm.nil?
      @dbm.close rescue nil
    end
    @dbm = nil
    remove_db(Gonzui::Config.new)
  end

  Words = ["foo", "bar", "baz", "quux"]

  def test_api
    config = Gonzui::Config.new
    remove_db(config)
    dbm = Gonzui::DBM.open(config)
    @dbm = dbm
    dbm.is_a?(Gonzui::BDBDBM)
    dbm.respond_to?(:find_all_by_prefix)
  end

  def _test_each_by_prefix(db)
    db.each_by_prefix("foo") {|k, v|
      assert_equal("foo", k)
      assert_equal(0, v)
    }

    db.each_by_prefix("ba") {|k ,v|
      case k
      when "bar"
        assert_equal(v, 1)
      when "baz"
        assert_equal(v, 2)
      when
        assert(false)
      end
    }
  end

  def _test_delete_both(db)
    assert(db.include?("foo"))
    db.delete_both("foo", 1)
    assert(db.include?("foo"))
    db.delete_both("foo", 0)
    assert(!db.include?("foo"))
  end

  def _test_get_last_key(db)
    assert_equal("quux", db.get_last_key)
    db.delete("quux")
    assert_equal("baz", db.get_last_key)
  end

  def test_bdb_extentions
    file_name = File.dirname(__FILE__) + "/test.db"

    db = BDB::Btree.open(file_name, "test", BDB::CREATE, 0644,
                         "set_store_value" => Gonzui::AutoPack::Fixnum.store,
                         "set_fetch_value" => Gonzui::AutoPack::Fixnum.fetch)
    db.extend(Gonzui::BDBExtension)
    Words.each_with_index {|word, i|
      db[word] = i
    }

    _test_each_by_prefix(db)
    _test_delete_both(db)
    _test_get_last_key(db)

    File.unlink(file_name)
  end if false # [BUG] Segmentation fault
end
