#
# search.rb - search servlet
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  class SearchServlet < GonzuiAbstractServlet
    def self.mount_point
      "search"
    end

    def do_make_status_line(result)
      right = ""
      if result.nhits > 0
        qs = @search_query.string
        from = (@search_query.package or @search_query.path)
        qs = @search_query.simplified_string if from
        to = [result.nhits, @from + @nresults_per_page].min
        right = [:span]
        limit_exceeded_mark = if result.limit_exceeded? then "+" else "" end
        right.push(_("Results "), 
                   [:strong, commify(@from + 1)], " - ", 
                   [:strong, commify(to)], _(" of "), 
                   [:strong, commify(result.nhits)],
                   limit_exceeded_mark,
                   _(" for "),
                   [:strong, qs])
        right.push(_(" from "), [:strong, from]) if from
      end
      center =  [:a, {:href => make_google_uri(@search_query)},
        _("Google it")]
      return center, right
    end

    def make_expansion_link(item)
      if item.has_more_in_package?
        package_name = @dbm.get_package_name(item.package_id)
        # FIXME: it should be simplified.
        qs = sprintf("package:%s %s", package_name, 
                     @search_query.simplified_string)
        search_query = SearchQuery.new(@config, qs, @search_query.options)
        uri = make_search_uri(search_query)
        from = package_name
      elsif item.has_more_in_path?
        path = @dbm.get_path(item.path_id)
        qs = sprintf("path:%s %s", path, 
                     @search_query.simplified_string)
        search_query = SearchQuery.new(@config, qs, @search_query.options)
        uri = make_search_uri(search_query)
        from = File.basename(path)
      else
        assert_not_reached
      end
      dd = [:dd,[:a, {:href => uri, :class => "more" }, 
          sprintf(_("More results from %s"), from)]]
      return dd
    end

    def make_package_name_line(package_name)
      uri = make_markup_uri(package_name)
      dt = [:dt, {:class => "package"}, [:a, {:href => uri}, package_name]]
      return dt
    end

    def make_source_path_line(item, package_name, path, markup_uri)
      lineno_uri = make_lineno_uri(markup_uri, item.list.first.lineno)
      source_line = [:dt, {:class => "source"}, [:a, 
          {:href => lineno_uri}, 
          File.relative_path(path, package_name)]]
      file_info = @dbm.get_content_info(item.path_id)
      size = [:span, {:class => "size"}, 
        sprintf(_(" - %s - %s lines"), 
                format_bytes(file_info.size),
                commify(file_info.nlines))
              ]
      source_line.push(size)
    end

    def make_result_list_by_snippet(result)
      dl = [:dl]
      prev_package_id = nil
      nresults = 0

      result.each_from(@from) {|item|
        assert(item.list.length > 0)
        package_name = @dbm.get_package_name(item.package_id)

        if item.package_id != prev_package_id
          dt = make_package_name_line(package_name)
          dl.push(dt)
          prev_package_id = item.package_id
        end

        path = @dbm.get_path(item.path_id)
        markup_uri = make_markup_uri(path, @search_query)
        dt = make_source_path_line(item, package_name, path, markup_uri)
        dl.push(dt)

        #
        # FIXME: if the target content is a text file, it's
        # better to make a snippet like google's one instead
        # of a line-oriented style.
        #
        content = @dbm.get_content(item.path_id)
        maker = SnippetMaker.new(content, item, markup_uri)
        pre = maker.make_line_oriented_kwic
        dl.push([:dd, pre])

        if item.has_more?
          link = make_expansion_link(item)
          dl.push(link)
        end
        nresults += 1
        break if nresults >= @nresults_per_page
      }
      return dl
    end

    def make_result_list_like_grep(result)
      assert_equal(1, result.length)
      dl = [:dl]
      item = result.first

      package_name = @dbm.get_package_name(item.package_id)
      path = @dbm.get_path(item.path_id)
      markup_uri = make_markup_uri(path, @search_query)

      dl.push(make_package_name_line(package_name))
      dl.push(make_source_path_line(item, package_name, path, markup_uri))

      content = @dbm.get_content(item.path_id)
      maker = SnippetMaker.new(content, item, markup_uri)
      snippet = maker.make_context_grep
      dl.push([:dd, snippet])
      return dl
    end

    def do_make_navi(from)
      make_search_uri(@search_query, 
                      :from => from,
                      :nresults_per_page => @nresults_per_page)
    end

    def redirect_to_uri(uri)
      @response.set_redirect(HTTPStatus::MovedPermanently, uri)
      assert_not_reached
    end

    # FIXME: it's not used 
    def redirect_to_single_result(result)
      item = result.first
      occ = item.list.first
      path = @dbm.get_path(item.path_id)
      lineno = (occ.lineno or 1)
      markup_uri = make_markup_uri(path, @search_query)
      lineno_uri = make_lineno_uri(markup_uri, lineno)
      redirect_to_uri(lineno_uri)
    end


    def make_not_found_message
      message = [:div, {:class => "message"},
        sprintf(_("No contents were found matching your search - %s."), 
                @search_query.string)
      ]
      return message
    end

    def make_query_error_message(e)
      message =[:div]
      message.push(make_not_found_message)
      message.push([:div, {:class => "message"}, _(e.message)])
      return message
    end

    def make_result_content(result)
      @from = 0 if @from >= result.length

      if result.empty?
        make_not_found_message
      elsif result.single_path?
        make_result_list_like_grep(result)
      else
        make_result_list_by_snippet(result)
      end
    end

    def redirect_if_necessary
      if @search_query.empty?
        redirect_to_uri(make_top_uri)
      elsif @search_query.path_only?
        markup_uri = make_markup_uri(@search_query.path, @search_query)
        redirect_to_uri(markup_uri)
      elsif @search_query.package_only?
        markup_uri = make_markup_uri(@search_query.package, @search_query)
        redirect_to_uri(markup_uri)
      end
    end

    def make_result_navi(result)
      make_navi(result.length, @from, @nresults_per_page, @config.max_pages)
    end

    def make_notice
      if @search_query.ignored_words.empty?
        return ""
      else
        div = [:div, {:class => "notice"}]
        message = 
          sprintf(_("\"%s\" (and any subsequent words) was ignored because queries are limited to %d words."),
                  @search_query.ignored_words.first,
                  @config.max_words
                  )
        div.push(message)
        return div
      end
    end

    def do_GET(request, response)
      init_servlet(request, response)
      log(@search_query.string)

      title = make_title(@search_query.string)
      html = make_html
      head = [:head, title,  make_script, *make_meta_and_css]
      body = [:body]
      body.push(make_h1)
      body.push(make_search_form)

      result = nil
      navi = nil
      begin
        @search_query.validate
        redirect_if_necessary

        searcher = Searcher.new(@dbm, @search_query, 
                                @config.max_results_overall)
        result = searcher.search
        content = make_result_content(result)
        if result.length > @nresults_per_page
          navi = make_result_navi(result)
        end
      rescue QueryError => e
        result = SearchResult.new
        content = make_query_error_message(e)
      end
      status_line = make_status_line(_("Search"), result)

      body.push(make_notice)
      body.push(status_line)
      body.push(content)
      body.push(navi) if navi

      body.push(make_footer)
      html.push(head)
      html.push(body)
      set_content_type_text_html
      response.body = format_html(html)
    end

    GonzuiServlet.register(self)
  end
end
