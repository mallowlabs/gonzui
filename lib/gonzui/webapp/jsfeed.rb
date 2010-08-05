#
# jsfeed - javascript-feed servlet
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  class JSFeedServlet < GonzuiAbstractServlet
    def self.mount_point
      "jsfeed"
    end

    def do_GET(request, response)
      init_servlet(request, response)
      path = make_path
      log(path)

      from = to = nil
      if m = /^(\d+)-(\d+)$/.match(request.query_string)
        from = m[1].to_i
        to   = m[2].to_i
      end

      if from and to
        path_id = @dbm.get_path_id(path)
        if path_id
          content = @dbm.get_content(path_id)
          lineno = 0
          lines = []
          range = Range.new(from, to)
          content.each_line {|line|
            lineno += 1
            if range.include?(lineno)
              line_with_lineno = sprintf("%5d: %s", lineno, line)
              line_with_lineno.chop!
              lines.push(HTMLUtils.escape(line_with_lineno))
            end
          }
          snippet = lines.join("<br />")
          response.body = sprintf("document.writeln('<pre>%s</pre>');", 
                                  snippet)
          response['Content-Type'] = "application/x-javascript"
        else 
          response.body = sprintf("%s: not found", path)
          response.status = 404
          response['Content-Type'] = "text/html"
        end
      else
        response.body = "invalid query"
        response['Content-Type'] = "text/html"
      end
    end

    GonzuiServlet.register(self)
  end
end
