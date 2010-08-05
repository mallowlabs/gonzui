#! /usr/bin/env ruby
require '_load_path.rb'
require 'test/unit'
require 'gonzui'
require '_test-util'

class DeltaDumperTest < Test::Unit::TestCase
  include Gonzui::DeltaDumper

  def test_fixnums
    list = [
      [[1,2,3,4,5,6], [1,1,1,1,1,1]],
      [[0,0,0,0,0,0], [0,0,0,0,0,0]],
      [[1,1,2,3,5,8], [1,0,1,1,2,3]],
    ]
    list.each {|original, encoded|
      tmp = original.dup
      assert_equal(encoded,  encode_fixnums(tmp))
      assert_equal(original, decode_fixnums(tmp))
    }
  end

  def test_fixnums_with_broken_data
    broken_data = [
      nil, 
      "",
      [1,2,nil,3],
      [1,2,3,2,1]
    ]
    broken_data.each {|list|
      begin
        encode_fixnums(list)
        assert_not_reached
      rescue ArgumentError, TypeError => e
      end
    }
  end

  def test_tuples
    list = [
      [[1,2,3,4,5,6], [1,2,2,2,2,2], 2, 2],
      [[1,2,3,4,5,6], [1,2,2,4,2,6], 1, 2],
    ]
    list.each {|original, encoded, dsize, usize|
      tmp = original.dup
      assert_equal(encoded,  encode_tuples(tmp, dsize, usize))
      assert_equal(original, decode_tuples(tmp, dsize, usize))
    }
  end

  def test_tuples_with_broken_data
    broken_data = [
      [nil, 2, 2],
      [[1,2,3,4,5], 2, 2],
      [[1,2,3,4,5,6], 3, 2],
      [[1,2,nil,4,5,6], 2, 2],
      [[1,2,3,3,2,1], 2, 2]
    ]
    broken_data.each {|list, dsize, usize|
      begin
        encode_tuples(list, dsize, usize)
        assert_not_reached
      rescue ArgumentError, TypeError => e
      end
    }
  end
end

