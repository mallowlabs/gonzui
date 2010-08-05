#! /usr/bin/env ruby
require '_load_path.rb'
require '_external_tools.rb'
require 'test/unit'
require 'gonzui'
require 'ftools'
require '_test-util'

class VCSTest < Test::Unit::TestCase
  include TestUtil
  include Gonzui::Util

  def prepare
    make_dist_tree
    config = Gonzui::Config.new
    config.quiet = true
    remove_db(config)
    return config
  end

  def test_cvs
    config = prepare
    make_cvs
    cvs = Gonzui::CVS.new(config, cvsroot, "foo")
    cvs.extract
    cached_foo = File.join(config.cache_directory, "foo")
    entries = Dir.entries_without_dots(cached_foo)
    FOO_FILES.each {|base_name|
      assert(entries.include?(base_name))
    }
    remove_cvs
  end if (CVS_)

  def test_svn
    config = prepare
    svnroot_uri = make_svn
    svn = Gonzui::Subversion.new(config, svnroot_uri, "foo")
    svn.extract
    cached_foo = File.join(config.cache_directory, "foo")
    entries = Dir.entries_without_dots(cached_foo)
    FOO_FILES.each {|base_name|
      assert(entries.include?(base_name))
    }
    remove_svn
  end if (SVN_)

  def test_git
    config = prepare
    gitroot = make_git
    git = Gonzui::Git.new(config, gitroot, "foo")
    git.extract
    cached_foo = File.join(config.cache_directory, "foo")
    entries = Dir.entries_without_dots(cached_foo)
    FOO_FILES.each {|base_name|
      assert(entries.include?(base_name))
    }
    remove_git
  end if (GIT_)
end if (CVS_ || SVN_ || GIT_)
