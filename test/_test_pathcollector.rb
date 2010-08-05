#! /usr/bin/env ruby
require '_load_path.rb'
require 'test/unit'
require 'gonzui'
require '_test-util'
include Gonzui

class PackageTest < Test::Unit::TestCase
  include TestUtil

  def test_package
    config = Config.new
    make_dist_tree
    directory = File.expand_path(File.join("foo", "foo-0.1"))
    package_name = File.basename(directory)
    source_url = URI.from_path(directory)
    collector = PathCollector.new(config, package_name, source_url)

    assert(collector.npaths > 0)
    collector.each {|url, normalized_path| 
      assert_equal(package_name, normalized_path.split(File::SEPARATOR).first)
      assert(File.file?(url.path))
    }
  end
end
