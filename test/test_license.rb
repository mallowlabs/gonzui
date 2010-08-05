#! /usr/bin/env ruby
require '_load_path.rb'
require 'test/unit'
require '_test-util'
require 'gonzui'

class LicenseTest < Test::Unit::TestCase
  TestCases = [
    ["GPL1", false, "GNU General Public License version 1"],
    ["GPL2", false, "GNU General Public License version 2"],
    ["LGPL1", false, "GNU Library Public License version 1"],
    ["LGPL2", false, "GNU Library Public License version 2"],
    ["LGPL2.1", false, "GNU Lesser Public License version 2.1"],
    ["Other", false, "My own license version 999"],

    ["GPL2", false, "GNU GENERAL PUBLIC LICENSE VERSION 2"],
    ["GPL2", false, "GNU  GENERAL    PUBLIC    LICENSE VERSION  2"],
    ["GPL2", false, "GNU/GENERAL/PUBLIC/LICENSE/VERSION/2"],

    ["GPL2", false, '
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
'
    ],

    ["GPL2", false, '
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#
# This is foobar version 1.  <= confusing!
'
    ],

    ["GPL2", true, '
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.'
    ],
  ]

  def test_license_detector
    TestCases.each {|abbrev, allow_later_p, text|
      detector = Gonzui::LicenseDetector.new(text)
      license = detector.detect
      assert_equal(abbrev, license.abbrev)
      assert_equal(allow_later_p, license.allow_later?)
    }
  end
end

