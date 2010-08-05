#
# source.rb - source servlet
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  class SourceServlet < GonzuiAbstractServlet
    def self.mount_point
      "source"
    end

    def do_GET(request, response)
      init_servlet(request, response)
      path = make_path
      log(path)

      path_id = @dbm.get_path_id(path)
      if path_id
        content = @dbm.get_content(path_id)
        response.body = content
        mime_type = get_mime_type(path)
        response["Content-Type"] = mime_type
      else 
        response.body = sprintf("%s: not found", path)
        response.status = 404
      end
    end

    GonzuiServlet.register(self)
  end
end
