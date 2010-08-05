#! /usr/bin/env ruby
require '_load_path.rb'
require 'test/unit'
require 'gonzui'
require '_test-util'

class ContentTest < Test::Unit::TestCase
  def test_content
    text = "foo"
    mtime = Time.now
    content = Gonzui::Content.new(text, mtime)
    assert_equal(text, content.text)
    assert_equal(text.length, content.length)
    assert_equal(mtime, content.mtime)
  end
end

