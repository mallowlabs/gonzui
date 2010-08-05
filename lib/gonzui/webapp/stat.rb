#
# stat.rb - statistics servlet
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  class StatisticsServlet < GonzuiAbstractServlet
    def self.mount_point
      "stat"
    end

    RankingMax = 100

    def choose_tr_class(i)
      if (i + 1) % 2 == 0 then "even" else "odd" end
    end

    def make_heading(*items)
      tr = [:tr, {:class => "heading"}]
      items.each {|string, klass, colspan|
        td = [:td, {:class => klass}, string]
        td[1][:colspan] = colspan if colspan
        tr.push(td)
      }
      return tr
    end

    def make_bar(freq, max)
      percentage = freq * 100 / max
      style = "width: #{percentage}px;"
      bar = [:div, {:class => "bar", :style => style}, ""]
    end

    def do_make_status_line
      []
    end

    def make_tr(first, second, third = nil)
      tr = [:tr]
      td1 = [:td, {:class => "first", :width => "76%"}, first]
      if third
        td2 = [:td, {:class => "nonfirst-right", :width => "12%"}, 
          commify(second)]
        td3 = [:td, {:width => "12%"}, third]
      else
        td2 = [:td, {:class => "nonfirst-center", :width => "24%"}, 
          commify(second)]
      end
      tr.push(td1)
      tr.push(td2)
      tr.push(td3) if td3
      return tr
    end

    def make_format_table
      table = [:table, {:class => "fullwidth"}]
      heading = make_heading([_("Contents by Format"), "first", 3])
      table.push(heading)
      formats = []
      max = -1
      @dbm.each_format {|format_id, format_abbrev, format_name|
        ncontents = @dbm.get_ncontents_by_format_id(format_id)
        formats.push([format_id, format_abbrev, format_name, ncontents])
        max = [max, ncontents].max
      }
      return if formats.empty?
      formats = formats.sort_by {|id, abbr, name, ncontents| - ncontents}
      formats.each_with_index {|item, i|
        id, abbr, name, ncontents = item
        text = name
        tr = make_tr(text, ncontents, make_bar(ncontents, max))
        k = choose_tr_class(i)
        tr.insert(1, {:class => k})
        table.push(tr)
      }
      return table
    end

    def make_overview_table
      table = [:table, {:class => "fullwidth"}]
      heading = make_heading([_("Overview"), "first", 2])
      table.push(heading)
      trs = []
      trs << make_tr(_("Packages"),        @dbm.get_npackages)
      trs << make_tr(_("Contents"),           @dbm.get_ncontents)
      trs << make_tr(_("Indexed Contents"),   @dbm.get_ncontents_indexed)
      trs << make_tr(_("Binary Contents"),    @dbm.get_ncontents - @dbm.get_ncontents_indexed)
      trs << make_tr(_("Lines of Indexed Contents"),   @dbm.get_nlines_indexed)
      trs << make_tr(_("Indexed Keys"),    @dbm.get_nwords)
      trs << make_tr(_("Formats"),         @dbm.get_nformats)
      trs.each_with_index {|tr, i|
        k = choose_tr_class(i)
        tr.insert(1, {:class => k})
        table.push(tr)
      }
      return table
    end

    def make_top_page
      title = make_title( _("Statistics"))
      content = [:div]
      content.push(make_overview_table)
      content.push(make_format_table)
      status_line = make_status_line(_("Statistics"))
      return title, status_line, content
    end

    def do_GET(request, response)
      init_servlet(request, response)
      log()

      @path = make_path
      title, status_line, content = make_top_page
      
      html = make_html
      head = [:head, title, make_script, *make_meta_and_css]
      body = [:body]
      body.push(make_h1)
      body.push(make_search_form)
      body.push(status_line)
      body.push(content)
      body.push(make_footer)
      html.push(head)
      html.push(body)
      set_content_type_text_html
      response.body = format_html(html)
    end

    GonzuiServlet.register(self)
  end
end
