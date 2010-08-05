#
# webrick.rb - webrick enhancements
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

require 'webrick'
include WEBrick

module WEBrick
  class HTTPRequest
    # FIXME: it should be deleted if WEBRick supports the method
    def parse_accept_language
      if self["Accept-Language"]
        tmp = []
        parts = self["Accept-Language"].split(/,\s*/)
        parts.each {|part|
          if m = /^([\w-]+)(?:;q=([\d]+(?:\.[\d]+)))?$/.match(part)
            lang = m[1]
            q = (m[2] or 1).to_f
            tmp.push([lang, q])
          end
        }
        @accept_language = 
          tmp.sort_by {|lang, q| q}.map {|lang, q| lang}.reverse
      else
        @accept_language = ["en"] # FIXME: should be customizable?
      end
    end

    def accept_language
      unless @accept_language
        parse_accept_language
      end
      return @accept_language
    end

    def gzip_encoding_supported?
      /\bgzip\b/.match(self["accept-encoding"])
    end
  end
end

