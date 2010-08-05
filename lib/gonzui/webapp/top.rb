#
# top.rb - top page servlet
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  class TopPageServlet < GonzuiAbstractServlet
    def self.mount_point
      ""
    end

    def validate_request
      return if @request.path_info == "/" or @request.path_info.empty?
      if @request.path_info == "/favicon.ico"
        uri = make_doc_uri("favicon.ico")
        @response.set_redirect(HTTPStatus::MovedPermanently, uri)
      else
        raise HTTPStatus::NotFound.new("not found")
      end
      assert_not_reached
    end

    def do_GET(request, response)
      init_servlet(request, response)
      validate_request
      log()

      title = make_title
      html = make_html
      head = [:head, title, make_script, *make_meta_and_css]
      body = [:body]

      content = [:div, {:class => "center"}, 
        make_h1, 
        make_search_form(:central => true),
      ]
      footer = make_footer
      summary = [
        [:br],
        sprintf(_("Searching %s packages of %s contents"), 
                commify(@dbm.get_npackages),
                commify(@dbm.get_ncontents))
      ]
      footer.push(*summary)
      
      content.push(footer)
      body.push(content)
      html.push(head)
      html.push(body)
      set_content_type_text_html
      response.body = format_html(html)
    end

    GonzuiServlet.register(self)
  end
end

