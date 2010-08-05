#
# filehandler.rb - file handler servlet
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  class FileHandler < WEBrick::HTTPServlet::FileHandler
    def self.mount_point
      "doc"
    end

    def initialize(server, config, logger, dbm, catalogs)
      super(server, config.doc_directory)
    end

    GonzuiServlet.register(self)
  end
end
