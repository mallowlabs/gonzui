#
# license.rb - detect types of licenses with heuristics
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  LicenseRegistry = []

  class License
    def initialize(abbrev, name, regexp)
      @abbrev = abbrev
      @name = name
      @regexp = regexp
      @allow_later_p = false
    end
    attr_reader :abbrev
    attr_reader :name
    attr_reader :regexp

    def allow_later
      @allow_later_p = true
    end

    def allow_later?
      @allow_later_p
    end
  end

  LicenseRegistry << License.new("GPL1",  
                                 "GNU General Public License version 1",
                                 /GNU General Public License .*?version 1/i
                                 )
  LicenseRegistry << License.new("GPL2",  
                                 "GNU General Public License version 2",
                                 /GNU General Public License .*?version 2/i
                                 )
  LicenseRegistry << License.new("LGPL1", 
                                 "GNU Library Public License version 1",
                                 /GNU Library Public License .*?version 1/i
                                 )
  LicenseRegistry << License.new("LGPL2", 
                                 "GNU Library Public License version 2",
                                 /GNU Library Public License .*?version 2/i
                                 )
  LicenseRegistry << License.new("LGPL2.1",
                                 "GNU Lesser Public License version 2.1",
                                 /GNU Lesser Public License .*?version 2\.1/i
                                 )
  LicenseRegistry << License.new("Perl",
                                 "Perl's License",
                                 /under the same terms as Perl/i
                                 )
  LicenseRegistry << License.new("Ruby",
                                 "Ruby's License",
                                 /under the same terms as Ruby|Ruby's license/i
                                 )


  OtherLicense = License.new("Other", "Other License", "")

  class LicenseDetector
    def initialize(text)
      len = 512
      @chunk = (text[0, len] or "")  # first 512 bytes
      @chunk << (text[text.length - len, len] or "") # last 512 bytes
      @chunk.gsub!(/[^\w.']+/, " ")
    end

    def allow_later?
      regexp = /or (at your option )?any later version/i
      return regexp.match(@chunk)
    end

    def detect
      candidates = []
      LicenseRegistry.each {|license|
        if m = license.regexp.match(@chunk)
          if allow_later?
            license = license.clone
            license.allow_later
          end
          candidates.push([m[0].length, license])
        end
      }
      if candidates.empty?
        return OtherLicense
      else
        license_of_shortest_match = 
          candidates.min {|a, b| a.first <=> b.first }.last
        return license_of_shortest_match
      end
    end
  end
end
