#! /usr/bin/env ruby
require '_load_path.rb'
require 'test/unit'
require 'gonzui'
require '_test-util'

class InfoTest < Test::Unit::TestCase
  TYPE_TABLE = [:fundef, :funcall, :fundecl]

  def test_word_info
    word_id = 0
    word = "foo"
    path_id = 100
    seqno = 0
    byteno = 300
    lineno = 200
    TYPE_TABLE.each_with_index {|type, type_id|
      values = [word_id, path_id, seqno, byteno, type_id, type, lineno]
      info = Gonzui::WordInfo.new(*values)
      assert_equal(word_id, info.word_id)
      assert_equal(path_id, info.path_id)
      assert_equal(lineno, info.lineno)
      assert_equal(byteno, info.byteno)
      assert_equal(type_id, info.type_id)
      assert_equal(type, info.type)

      assert_equal(values, info.values)
    }
  end

  def test_digest_info
    byteno = 100
    length = 5
    TYPE_TABLE.each_with_index {|type, type_id|
      values = [byteno, length, type_id, type]
      info = Gonzui::DigestInfo.new(*values)
      assert_equal(byteno, info.byteno)
      assert_equal(length, length)
      assert_equal(type_id, info.type_id)
      assert_equal(values, info.values)
    }
  end

  def test_occurrence
    o = Gonzui::Occurrence.new(10, 1, 5)
    assert_equal((10...15), o.range)
    assert_equal(15, o.end_byteno)
  end

  def test_content_info
    i = {
      :size => 123,
      :mtime => Time.at(0),
      :itime => Time.now,
      :format_id => 0,
      :license_id => 1,
      :nlines => 10,
      :indexed_p => true,
    }
    Gonzui::ContentInfo.members.each {|name|
      name = name.intern
      i.include?(name)
    }
    info = Gonzui::ContentInfo.new(i[:size], i[:mtime], i[:itime], i[:format_id], 
                           i[:license_id], i[:nlines], i[:indexed_p])
    info.members.each {|name|
      name = name.intern
      assert_equal(i[name], info.send(name))
    }
    i.each_key {|name|
      assert_equal(i[name], info.send(name))
    }
  end

  def test_minus_mtime
    size = 100
    mtime = -1
    itime = Time.now.to_i
    format_id = license_id = nlines = indexed_p = 0
    packed = Gonzui::ContentInfo.dump(size, mtime, itime, format_id, 
                              license_id, nlines, indexed_p)
    assert(packed.is_a?(String))
  end
end
