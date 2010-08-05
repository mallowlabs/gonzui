#! /usr/bin/env ruby
require File.dirname(__FILE__) + '/test_helper.rb'
require '_test-util'

class TextTokenizerTest < Test::Unit::TestCase
  include TestUtil

  def _test_collect(text)
    list = []
    Gonzui::TextTokenizer.each_word(text) {|word, pos|
      assert(word.is_a?(String))
      assert(pos.is_a?(Integer))
      list.push([word, pos])
    }
    return list
  end

  def _test_with_words(words, delim)
    text = words.join(delim)
    list = _test_collect(text)

    pos = 0
    words.each_with_index {|word, i|
      assert_equal(word, list[i][0])
      assert_equal(pos, list[i][1])
      pos += word.length + delim.length
    }
  end

  def _test_text(text, n)
    list = _test_collect(text)
    assert_equal(n, list.length)
  end

  def test_each
    words = ["foo", "bar", "baz"]
    _test_with_words(words, " ")
    _test_with_words(words, "\n")
    _test_with_words(words, ", ")
    _test_with_words(words, ",\n")
    _test_with_words(words, "!#%&\n\n\n@@")

    _test_text("foo_bar", 1)
    _test_text("あ", 1)  # single multi-byte character
    _test_text("あい", 2) # two multi-byte characters
  end
end
