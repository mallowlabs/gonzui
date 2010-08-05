#! /usr/bin/env ruby -Ku
# -*- coding: utf-8-unix -*-
require File.dirname(__FILE__) + '/test_helper.rb'
require '_test-util'

class GetTextTest < Test::Unit::TestCase
  include Gonzui::GetText

  CATALOG_FILE_NAME = "catalog.ja"
  CATALOG = {
    "hello" => "こんにちは"
  }

  def make_catalog
    File.open(CATALOG_FILE_NAME, "w") {|f|
      f.puts "{"
      CATALOG.each {|key, value|
        f.printf('  "%s" => "%s",', key, value)
        f.puts
      }
      f.puts "}"
    }
  end

  def remove_catalog
    File.unlink(CATALOG_FILE_NAME)
  end

  def test_gettext
    make_catalog
    assert_equal("hello", _("hello"))
    catalog_repository = Gonzui::CatalogRepository.new(".")
    catalog = catalog_repository.choose("ja")
    assert_equal(catalog, load_catalog("catalog.ja"))
    set_catalog(catalog)
    assert_equal("こんにちは", _("hello"))

    remove_catalog
  end

  def test_validator
    validator = Gonzui::CatalogValidator.new(__FILE__, CATALOG)
    validator.validate
    assert_equal(true, validator.ok?)

    validator = Gonzui::CatalogValidator.new(__FILE__, {})
    validator.validate
    assert_equal(false, validator.ok?)
  end
end
