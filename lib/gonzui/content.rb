#
# content.rb - content implementation
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  Content = Struct.new(:text, :mtime, :path)
  class Content
    def length
      self.text.length
    end
  end
end
