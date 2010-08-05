#! /usr/bin/env ruby
require '_load_path.rb'
require '_external_tools.rb'
require 'test/unit'
require 'gonzui'
require '_test-util'

class DBMTest < Test::Unit::TestCase
  include TestUtil

  def test_dbm_create
    config   = Gonzui::Config.new
    remove_db(config)
    dbm = Gonzui::DBM.open(config)
    assert(dbm.is_a?(Gonzui::AbstractDBM))
    dbm.close
  end

  def test_dbm_create_with_block
    config   = Gonzui::Config.new
    remove_db(config)
    Gonzui::DBM.open(config) {|dbm|
      assert(dbm.is_a?(Gonzui::AbstractDBM))
    }
  end

  def _test_consistent_p(dbm)
    assert(dbm.consistent?)
  end

  def _test_content_info(dbm)
    dbm.each_package_name {|package_name|
      package_id = dbm.get_package_id(package_name)
      assert(package_id)
      path_ids = dbm.get_path_ids(package_id)
      path_ids.each {|path_id|
        stat = dbm.get_content_info(path_id)
        assert(stat.is_a?(Gonzui::ContentInfo))
        content = dbm.get_content(path_id)
        assert_equal(stat.size, content.length)
        assert(stat.itime >= stat.mtime)
        assert((Time.now.to_i - stat.itime) < 600) # within 10 minutes
      }
    }
  end

  def _test_each_foo(dbm)
    dbm.each_package_name {|package_name|
      assert_equal(FOO_PACKAGE, package_name)
    }

    dbm.each_db_name {|db_name|
      assert(db_name.is_a?(String))
      assert(dbm.respond_to?(db_name))
    }
  end

  def _test_get_foo(dbm)
    make_dist_tree
    package_id = dbm.get_package_id(FOO_PACKAGE)
    dbm.get_path_ids(package_id).each {|path_id|
      path = dbm.get_path(path_id)
      assert(FOO_FILES.include?(File.basename(path)))
      assert_equal(path_id, dbm.get_path_id(path))
      content = dbm.get_content(path_id)
      content = File.read(File.join("foo", path))
      assert_equal(content, content)
      dbm.get_word_ids(path_id).each {|word_id|
        FOO_SYMBOLS.include?(dbm.get_word(word_id))
      }
      assert_equal(0, package_id)
      assert_equal(FOO_PACKAGE, dbm.get_package_name(package_id))
    }
  end

  def _test_foo_find(dbm)
    found_types = []
    [:find_all, :find_all_by_regexp, :find_all_by_prefix].each {|search_method|
      FOO_SYMBOLS.each {|word|
        tuples = dbm.send(search_method, word)
        assert(tuples.is_a?(Array))
        assert_equal(false, tuples.empty?)
        tuples.each {|info|
          type = dbm.get_type(info.type_id)
          assert(type.is_a?(Symbol))
          found_types.push(type)

          assert(info.is_a?(Gonzui::WordInfo))
          if search_method == :find_all
            assert_equal(word, dbm.get_word(info.word_id))
          else
            assert(dbm.get_word(info.word_id).index(word))
          end
          assert(info.byteno.is_a?(Fixnum))
          assert(info.lineno.is_a?(Fixnum))
          assert(info.type_id.is_a?(Fixnum))
          assert(info.path_id.is_a?(Fixnum))
          path = dbm.get_path(info.path_id)
          assert(FOO_FILES.include?(File.basename(path)))
        }
      }
      [:fundef, :funcall, :fundecl].each {|type|
        assert(found_types.include?(type))
      }
      assert(dbm.send(search_method, "__not_existing_word__").empty?)
    }
  end

  def _test_digest(dbm)
    path_id = dbm.get_path_id(File.join(FOO_PACKAGE, "foo.c"))
    content = dbm.get_content(path_id)
    digest = dbm.get_digest(path_id)
    digest.each {|info|
      assert(info.is_a?(Gonzui::DigestInfo))
      word = content[info.byteno, info.length]
      if word
        assert_equal(word.length, info.length)
        assert_equal(word, content[info.byteno, info.length])
      end
    }
  end

  def _test_close(dbm)
    begin
      dbm.close
      dbm.close
      assert(false)
    rescue Gonzui::DBMError => e
      assert(true)
    end

    begin
      dbm.get_npackages
      assert(false)
    rescue BDB::Fatal => e # closed DB
      assert(true)
    end
  end

  def test_bdb
    tmp = "test.#{$$}.db"
    db = BDB::Btree.open(tmp, nil, BDB::CREATE, 0644,
                         "set_flags" => BDB::DUPSORT)
    db["foo"] = "1"
    db["foo"] = "2"
    assert_equal(2, db.duplicates("foo").length)

    # The assert failed with Ruby BDB 0.5.1 or older due to
    # BDB::Btree#duplicates's bug. The bug was fixed in BDB
    # 0.5.2.
    assert_equal(0, db.duplicates("f").length)
    assert_equal(0, db.duplicates("").length)
    db.close
    File.unlink(tmp)
  end

  def test_dbm_operations
    config = Gonzui::Config.new
    remove_db(config)

    make_archives
    add_package(config)

    dbm = Gonzui::DBM.open(config)
    _test_content_info(dbm)
    _test_each_foo(dbm)
    _test_get_foo(dbm)
    _test_foo_find(dbm)
    _test_digest(dbm)
    _test_close(dbm)
    remove_db(config)
  end
end if (ARC_)
