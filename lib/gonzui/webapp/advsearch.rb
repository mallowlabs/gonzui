#
# advsearch.rb - advanced search servlet
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  class AdvancedSearchServlet < GonzuiAbstractServlet
    def self.mount_point
      "advsearch"
    end

    def do_make_status_line
      []
    end

    def make_target_select
      tt = get_short_name(:target_type)
      select = [:select, {:name => tt}]
      oall = [:option, {:type => "radio", :name => tt, 
              :value => ""}, _("All")]
      select.push(oall)
      LangScan::Type.each_group {|group|
        og = [:optgroup, {:label => _(group.name)}]
        added_p = false
        group.each {|type_info|
          if @dbm.has_type?(type_info.type)
            o = [:option, {:type => "radio", :name => tt, 
                :value => type_info.type}, _(type_info.name)]
            og.push(o)
            added_p = true
          end
        }
        select.push(og) if added_p
      }
      return select
    end

    def make_nresults_select
      nr = get_short_name(:nresults_per_page)
      select = [:select, {:name => nr}]
      @config.nresults_candidates.each {|n|
        o = [:option, {:type => "radio", :name => nr, 
            :value => n}, sprintf(_("%d results"), n)]
        select.push(o)
      }
      return select
    end

    def make_target_specific_search_form
      form = [:form, { :method => "get", 
                       :action => make_uri_general(SearchServlet)}]

      ikeyword = [:input, {:type => "text", :size => 30, 
          :name => get_short_name(:basic_query),
          :value => @search_query.keywords.join(" ")}]
      iphrase = [:input, {:type => "text", :size => 30, 
          :name => get_short_name(:phrase_query),
          :value => (@search_query.phrases.first or []).join(" ")}]

      nresults_select = make_nresults_select

      isubmit = [:input, {:type => "submit", :value => _("Search")}]

      table = [:table]
      table.push([:tr, [:td, {:width => "20%"}, _("Keyword")], 
                   [:td, {:width => "30%"}, ikeyword], 
                   [:td, {:width => "15%"}, nresults_select],
                   [:td, {:width => "15%"}, isubmit]])
      table.push([:tr, [:td, {:width => "20%"}, _("Phrase")], 
                   [:td, {:width => "30%"}, iphrase]])

      table.push([:tr])

      target_select = make_target_select
      table.push([:tr, [:td, _("Target")], 
                   [:td, target_select], [:td]])

      format_select = make_format_select
      table.push([:tr, [:td, _("Format")], [:td, format_select], [:td]])

      license_select = make_license_select
      table.push([:tr, [:td, _("License")], [:td, license_select], [:td]])

      form.push(table)
      return form
    end

    def make_advanced_search_form
      form = make_target_specific_search_form
      return [:div, {:class =>"advanced-search"}, form]
    end

    def do_GET(request, response)
      init_servlet(request, response)
      log()

      html = make_html
      title = make_title(_("Advanced Search"))
      head = [:head, title, *make_meta_and_css]
      body = [:body]

      h1 = make_h1
      status_line = make_status_line(_("Advanced Search"))
      content = make_advanced_search_form
      footer = make_footer
      body.push(h1, status_line, content, footer)

      html.push(head)
      html.push(body)
      set_content_type_text_html
      response.body = format_html(html)
    end

    GonzuiServlet.register(self)
  end
end

