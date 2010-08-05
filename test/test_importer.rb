#! /usr/bin/env ruby
require '_load_path.rb'
require '_external_tools.rb'
require 'test/unit'
require 'fileutils'
require 'gonzui'
require '_test-util'

class ImporterTest < Test::Unit::TestCase
  include TestUtil

  include FileUtils

  def _test_import(url)
    config   = Gonzui::Config.new
    remove_db(config)
    make_archives

    importer = Importer.new(config)
    importer.import(url)
    begin
      importer.import(url)
      assert(false)
    rescue Gonzui::ImporterError => e
      assert(true)
    end
    summary = importer.summary
    assert(summary.is_a?(String))
    assert(/\d+/.match(summary))
    importer.finish
    remove_db(config)
  end

  def test_import_archive
    _test_import(URI.from_path(FOO_TGZ))
  end

  def test_import_by_apt
    _test_import(URI.for_apt("portmap"))
  end

  def test_import_unreadable_file
    tmp_directory = "tmp.unreadable.#{Process.pid}"
    mkdir_p(tmp_directory)

    unreadable = File.join(tmp_directory, "unreadable.txt")
    File.open(unreadable, "w") {|f| f.puts("unreadable") }
    readable = File.join(tmp_directory, "readable.txt")
    File.open(readable, "w") {|f| f.puts("readable") }

    File.chmod(0000, unreadable)
    begin
      _test_import(URI.from_path(tmp_directory))
    ensure
      File.chmod(0600, unreadable)
      rm_rf(tmp_directory)
    end
  end
end if (APT_ && ARC_)
