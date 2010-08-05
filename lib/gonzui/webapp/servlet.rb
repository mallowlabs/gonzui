#
# servlet.rb - servelt framework
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

module Gonzui
  module GonzuiServlet
    extend Util
    ServletRegistry = {}

    module_function
    def servlets
      ServletRegistry.values
    end

    def register(klass)
      mount_point = klass.mount_point
      assert(!ServletRegistry.include?(mount_point))
      ServletRegistry[mount_point] = klass
    end
  end

  module HTMLMaker
    def make_content_script_type
      [:meta, 
        {
          "http-equiv" => "content-script-type", 
          :content => "text/javascript"
        }
      ]
    end

    def make_css
      [:link, 
        { 
          :rel => "stylesheet", 
          :href => make_doc_uri("gonzui.css"),
          :media => "all", :type => "text/css" 
        }
      ]
    end

    def make_footer
      [:div, {:class => "footer"}, 
        [:a, {:href => make_markup_uri}, _("List of all packages")],
        " - ",
        [:a, {:href => make_stat_uri}, _("Statistics")],
        " - ",
        [:a, {:href => Gonzui::GONZUI_URI}, _("About gonzui")],
      ]
    end

    def make_html
      [:html, {:xmlns => "http://www.w3.org/1999/xhtml"}]
    end
    def make_meta
      [:meta, {:name => "robots", :content => "noarchive"}]
    end

    def make_meta_and_css
      [ make_meta, make_content_script_type, make_css ]
    end

    def make_title(sub_title = nil)
      if sub_title
        return [:title, sprintf("%s: %s", @config.site_title, sub_title)]
      else
        return [:title, @config.site_title]
      end
    end

    def make_h1
      [:h1, [:a, {:href => make_top_uri}, @config.site_title]]
    end

    def make_navi(nitems, from, max_per_page, max_pages = nil)
      return "" if nitems <= max_per_page
      navi = [:div, {:class => "navi"}]
      if from > 0
        f = [from - max_per_page, 0].max
        uri = do_make_navi(f)
        navi.push([:a, {:href => uri}, _("prev")], " ")
      end

      if nitems > max_per_page
        (0..((nitems - 1) / max_per_page)).each {|i|
          break if max_pages and i >= max_pages 
          f = i * max_per_page
          if f == from
            navi.push((i + 1).to_s + " ")
          else
            uri = do_make_navi(f)
            navi.push([:a, {:href => uri}, (i + 1).to_s], " ")
          end
        }
      end

      if from + max_per_page < nitems
        f = [from + max_per_page, 0].max
        uri = do_make_navi(f)
        navi.push([:a, {:href => uri}, _("next")])
      end
      return navi
    end

    def make_script
      [:script, {:type => "text/javascript", 
          :src => make_doc_uri("gonzui.js")}, ""]
    end

    def make_property_select(short_name, current_value, each, *excludes)
      select = [:select, {:name => short_name}]
      o = [:option, {:type => "radio", :name => short_name, :value => "all"}, 
        _("All")]
      select.push(o)
      @dbm.send(each) {|id, abbrev, name|
        next if excludes.include?(abbrev)
        o = [:option, 
          {:type => "radio", :name => short_name, :value => abbrev},
          _(name)]
        if abbrev == current_value
          o[1][:selected] = "selected"
        end
        select.push(o)
      }
      return select
    end

    def make_format_select
      make_property_select(get_short_name(:format),
                           @search_query.format,
                           :each_format, 
                           "binary")
    end

    def make_license_select
      make_property_select(get_short_name(:license),
                           @search_query.license,
                           :each_license)
    end

    def make_search_form(options = {})
      query = @search_query.string
      form = [:form,  {:method => "get", :action => 
          make_uri_general(SearchServlet)}]
      iquery  = [:input, {:type => "text", :size => 50, 
          :name => get_short_name(:basic_query), 
          :value => query}]
      isubmit = [:input, {:type => "submit", :value => _("Search")}]
      p = [:p]
      p.push(iquery)
      if options[:central]
        p.push([:br]) 
      else
        p.push(" ")
      end

      p.push(isubmit)
      select = make_format_select
      p.push([:br])
      p.push(_("Format: "))
      p.push(select)
      p.push(make_spacer)
      uri = make_advanced_search_uri(@search_query)
      p.push([:a, {:href => uri, :onclick => "passQuery(this)"},
               _("Advanced Search")])
      p.push([:script, "initFocus();"])
      form.push(p)
      return form
    end

    def make_spacer
      [:span, {:class => "spacer" }, " "]
    end

    def make_status_line(status_title, *options)
      status_line = [:table, {:class => "status"}]
      items = do_make_status_line(*options)
      right = (items.pop or "")

      tds = []
      tds.push([:td, {:class => "left"}, status_title])
      items.each {|item|
        tds.push([:td, {:class => "center"}, item])
      }
      unless right.empty?
        r = [:td, {:class => "right"}, right]
        r.push(" (", [:strong, sprintf("%.2f", Time.now - @start_time)],
               _(" seconds)"))
        tds.push(r)
      end
      status_line.push([:tr, *tds])
      return status_line
    end
  end

  class ServletError < GonzuiError; end

  class GonzuiAbstractServlet < HTTPServlet::AbstractServlet
    include Util
    include GetText
    include URIMaker
    include HTMLMaker

    def initialize(server, config, logger, dbm, catalog_repository)
      @server = server
      @config = config
      @logger = logger
      @dbm = dbm
      @catalog_repository = catalog_repository
      @servlet_name = /(\w+)Servlet$/.match(self.class.to_s)[1].downcase
      @start_time = Time.now
    end

    private
    def make_search_query(query)
      format = get_query_value(query, :format)
      license = get_query_value(query, :license)

      basic_query  = get_query_value(query, :basic_query)
      target_type  = get_query_value(query, :target_type)
      phrase_query = get_query_value(query, :phrase_query)
      query_string = ""
      query_string << target_type << ":" if target_type
      query_string << basic_query if basic_query
      if phrase_query
        query_string << " " unless basic_query.empty?
        query_string << '"' << phrase_query << '"'
      end
      @search_query = SearchQuery.new(@config, 
                                      query_string, 
                                      :format => format,
                                      :license => license)
    end

    def parse_request
      query = @request.query
      @from              = get_query_value(query, :from)
      @grep_pattern      = get_query_value(query, :grep_pattern)
      @display_language  = get_query_value(query, :display_language)
      @nresults_per_page = get_query_value(query, :nresults_per_page)

      @from = 0 if @from < 0
      @nresults_per_page = 1 if @nresults_per_page <= 0
      if @nresults_per_page > @config.max_results_per_page
        @nresults_per_page = @config.max_results_per_page
      end

      @search_query = make_search_query(query)
      @ip_address = @request.peeraddr[3]
    end

    def init_catalog
      if @display_language
        catalog = @catalog_repository.choose(@display_language)
        set_catalog(catalog)
      else
        accept_languages = @request.accept_language
        accept_languages.each {|lang|
          catalog = @catalog_repository.choose(lang)
          if catalog
            set_catalog(catalog)
            break
          end
        }
      end
    end

    public
    def get_mime_type(path)
      HTTPUtils.mime_type(path, @server[:MimeTypes])
    end

    # ex. image
    def get_media_type(path)
      get_mime_type(path).split("/").first
    end

    def format_html(html)
      formatter = XMLFormatter.new
      formatter.add_xml_declaration
      formatter.add_doctype
      return formatter.format(html)
    end

    def set_content_type_text_html
      @response["Content-Type"] = "text/html; charset=utf-8"
    end

    def init_servlet(request, response)
      @request  = request
      @response = response
      parse_request
      init_catalog
    end

    def log(message = nil)
      if message
        @logger.log("%s %s [%s]", @servlet_name, message, @ip_address)
      else
        @logger.log("%s [%s]", @servlet_name, @ip_address)
      end
    end

    def make_path
      path = @request.path_info.prechop
      return path
    end
  end
end
