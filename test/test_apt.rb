#! /usr/bin/env ruby
require File.dirname(__FILE__) + '/test_helper.rb'
require '_external_tools'
require '_test-util'

class AptTest < Test::Unit::TestCase
  def _test_apt_get_temporary_directory(aptget)
    assert(File.directory?(aptget.temporary_directory))
    aptget.clean
    assert_equal(false, File.directory?(aptget.temporary_directory))
  end

  def test_apt_get
    return unless Gonzui::AptGet.available?
    apt_type = Gonzui::AptGet.get_apt_type
    assert((apt_type == :rpm or apt_type == :deb))
    config = Gonzui::Config.new
    aptget = Gonzui::AptGet.new(config, "portmap")

    directory = aptget.extract
    assert(File.directory?(directory))

    _test_apt_get_temporary_directory(aptget)
  end

  def test_apt_get_nonexisting
    return unless Gonzui::AptGet.available?
    apt_type = Gonzui::AptGet.get_apt_type
    assert((apt_type == :rpm or apt_type == :deb))
    config = Gonzui::Config.new
    aptget = Gonzui::AptGet.new(config, "qpewrguiniquegnoqwiu")
    begin
      aptget.extract
      assert(false)
    rescue Gonzui::AptGetError => e
      assert(true)
    end

    _test_apt_get_temporary_directory(aptget)
  end
end if (APT_)

