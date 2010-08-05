#
# markup.rb - markup servlet
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

require 'stringio'
require 'zlib'
require 'strscan'

module Gonzui
  class TextBeautifier
    def initialize(content, digest, occurrences, search_uri)
      @content = content
      @digest = digest # to be destroyed
      @occurrences = occurrences # to be destroyed
      @search_uri = search_uri

      @break_points = [0, @content.length]
      @lines = {}
      pos = lineno = 0
      @content.each_line {|line|
        lineno += 1
        @break_points.push(pos)
        @lines[pos] = [lineno, line]
        pos += line.length
      }
      @digest.each {|info|
        @break_points.push(info.byteno)
        @break_points.push(info.end_byteno)
      }
      @occurrences.each {|occ|
        @break_points.push(occ.byteno)
        @break_points.push(occ.end_byteno)
      }
      @break_points.uniq!
      @break_points.sort!

      @info = @digest.shift
      @occ = @occurrences.shift
      @seen_ids = {}
      @latest_id = "0"
    end

    def make_line_mark(lineno)
      anchor = "l" + lineno.to_s
      [:span, {:class => "lineno", :onclick => "olnc(this);"},
        [:a, {:id => anchor, :name => anchor, :href => "#" + anchor}, 
          sprintf("%5d: ", lineno)]]
    end

    def choose_target_type
      case @info.type
      when :fundef 
        :funcall
      when :funcall
        :fundef
      when :fundecl
        :fundef
      else 
        assert_not_reached
      end
    end

    def decorate(text)
      unless @seen_ids.include?(text)
        @seen_ids[text] = @latest_id
        @latest_id = @latest_id.next
      end
      id = @seen_ids[text]
      inner = [:span, {:class => id, :onmouseover => "hl('#{id}');"}, text]
      part = [:span, {:class => @info.type.to_s}, inner]
        
      if LangScan::Type.function?(@info.type)
        tt = choose_target_type
        query_string =  sprintf("%s:%s", tt, HTTPUtils.escape_form(text))
        uri = @search_uri + query_string
        part = [:a, {:href => uri}, part]
      end
      return part
    end

    def markup_part(bp, ep)
      part =  @content[bp...ep]
      if @info and (bp == @info.byteno or @info.range.include?(bp))
        part = decorate(part)
        @info = @digest.shift if @info.end_byteno <= ep
      end
      if @occ and (bp == @occ.byteno or @occ.range.include?(bp))
        part = [:strong, {:class => "highlight"}, part]
        @occ = @occurrences.shift if @occ.end_byteno <= ep
      end
      return part
    end

    def make_lineno_part(bp)
      lineno, line = @lines[bp]
      [:span, {:class => "line", :title => line}, make_line_mark(lineno)]
    end

    def beautify
      code = []
      bp = @break_points.shift
      line = nil
      while not @break_points.empty?
        ep = @break_points.shift
        if @lines.include?(bp)
          code.push(line) if line
          line = make_lineno_part(bp)
        end
        part = markup_part(bp, ep)
        line.push(part)
        bp = ep
      end
      code.push(line) if line
      return code
    end
  end

  class MarkupServlet < GonzuiAbstractServlet
    def self.mount_point
      "markup"
    end

    def make_breadcrumbs(path)
      parts = path.split("/")
      breadcrumbs = (1 .. parts.length).map {|i| 
        [ parts[i - 1], parts[0, i]]
      }.map {|part, parts|
        path = parts.join("/")
        uri = make_markup_uri(parts.join("/"), @search_query)
        [:a, {:href => uri}, part]
      }
      (breadcrumbs.length - 1).times {|i|
        breadcrumbs.insert(i * 2 + 1, "/")
      }
      return [:span, *breadcrumbs]
    end

    def do_make_status_line(method)
      items = []

      case method
      when :markup_file
        if @path_id
          bare = [:a, {:href => make_source_uri(@path)}, 
            _("bare source")]
          permlink = [:a, {:href => make_markup_uri(@path)}, 
            _("permlink")]
          items.push(bare)
          items.push(permlink)
        end
      when :list_files
        if @total
          items.push([:span, [:strong, @total], _(" contents.")])
        end
      when :list_packages
        if @to and @total
          packages = [:span, _("Packages "), 
            [:strong, commify(@from + 1)], " - ",
            [:strong, commify(@to)], _(" of "),
            [:strong, commify(@total)], _(".")]
          items.push(packages)
        end
      end
      return items
    end

    def calc_ncolumns(items)
      sum = items.inject(0) {|a, b| 
        name = b.first
        a + name.length 
      }
      average = sum / items.length
      ncolumns = [40 / average, items.length].min
      ncolumns = 1 if ncolumns == 0
      return ncolumns
    end

    def make_table(items)
      table = [:table, {:class => "fullwidth"}]
      return table if items.empty?
      ncolumns = calc_ncolumns(items)
      width = sprintf("%d%%", 100/ncolumns)

      nrows = (items.length - 1) / ncolumns + 1
      nrows.times {|i|
        k = if (i + 1) % 2 == 0 then "even" else "odd" end
        row = [:tr, {:class => k}]
        ncolumns.times {|j|
          # item = items[j * nrows + i] # for vertical arrange
          item = items[i * ncolumns + j]
          value = if item
                    name, klass, image, uri, title = item
                    tr = [:tr]
                    if image
                      img = [:img, {:src => image, :alt => ""}]
                      tr << [:td, [:a, {:href => uri}, img]]
                    end
                    a = [:a, {:class => klass, :href =>uri,:title =>title}, name]
                    tr << [:td, a]
                    [:table, {:class => "item"}, tr]
                  else
                    make_spacer
                  end
          k = if j == 0 then "first" else "nonfirst" end
          td = [:td, {:width => width, :class => k}, value]
          row.push(td)
        }
        table.push(row)
      }
      return table
    end

    def make_title_for_path(path, file_p)
      title = if file_p 
                path_id = @dbm.get_path_id(path)
                info = @dbm.get_content_info(path_id)
                sprintf(_("Size: %s (%s lines)"),
                        format_bytes(info.size),
                        commify(info.nlines))
              else 
                ""
              end
      return title
    end

    def make_table_of_files(paths)
      items = paths.map {|path, file_p|
        basename = File.basename(path)
        klass = if file_p then "file" else "directory" end
        image = if file_p 
                  make_doc_uri("text.png")
                else 
                  make_doc_uri("folder.png")
                end
        uri = make_markup_uri(path, @search_query)
        title = make_title_for_path(path, file_p)
        [basename, klass, image, uri, title]
      }
      return make_table(items)
    end

    def make_table_of_packages(package_names)
      items = package_names.map {|package_name|
        package_id = @dbm.get_package_id(package_name)
        uri = make_markup_uri(package_name)
        title = ""
        [package_name, "directory", nil, uri, title]
      }
      return make_table(items)
    end

    def list_files
      path_parts = @path.split("/")
      depth = path_parts.length
      
      package_id = @dbm.get_package_id(@package_name)
      path_ids = @dbm.get_path_ids(package_id)
      paths = path_ids.map {|path_id|
        @dbm.get_path(path_id)
      }.map {|path| 
        path.split("/")
      }.find_all {|parts|
        parts.length > depth and parts[0, depth] == path_parts
      }.map {|parts|
        file_p = parts.length == depth + 1
        [parts[0, depth + 1].join("/"), file_p]
      }.uniq
      if paths.empty?
        return ""
      else
        @total = paths.length
        return make_table_of_files(paths)
      end
    end

    def do_make_navi(from)
      make_markup_uri("", nil, :from => from)
    end

    def list_packages 
      # FIXME: sorting every time is not efficient.
      all = []
      @dbm.each_package_name {|package_name|
        all.push(package_name)
      }
      all.sort!

      package_names = all[@from, @config.max_packages_per_page]
      if package_names
        @to = @from + package_names.length
        @total = all.length
        table = make_table_of_packages(package_names)
        navi = make_navi(all.length, @from, @config.max_packages_per_page)
        return [:div, table, navi]
      else
        return ""
      end
    end

    def markup_source
      content = @dbm.get_content(@path_id)
      digest  = @dbm.get_digest(@path_id)
      occurrences = if @search_query.string.empty?
                      []
                    else
                      search_query = @search_query.clone
                      search_query.path ||= @path
                      searcher = Searcher.new(@dbm, search_query, 
                                              @config.max_results_overall)
                      result = searcher.search
                      item = result.first
                      if item and not item.list.empty? 
                        item.list 
                      else
                        [] 
                      end
                    end
      search_uri = make_search_uri_partial("")
      beautifier = TextBeautifier.new(content, digest, occurrences, search_uri)
      return beautifier.beautify
    end

    def make_isearch_form
      isearch = [:div, {:class => "isearch"}]
      form = [:form, {:method => "get", :action => "",
        :onsubmit => "return false;"}]
      p = [:p]
      p.push(_("Search this content: "))
      p.push([:input, {:type => "text", :name => "g", :size => "20",
                 :onkeyup => "isearch(this.value);",
                 :value => ""
               }])
      p.push(" ")
      form.push(p)
      isearch.push(form)
      return isearch
    end

    def markup_file
      path = @dbm.get_path(@path_id)

      mime_type = get_mime_type(path)
      media_type = get_media_type(path)
      if media_type == "image"
        img = [:img, {:src => make_source_uri(path),
            :alt => path }]
        content = [:div, {:class => "image"}, img]
      elsif mime_type == "text/html"
        iframe = [:iframe, {:src => make_source_uri(path),
          :width => "100%", :height => "400"},
          [:a, {:href => make_source_uri(path)}, path]
        ]
        content = iframe
      else
        content = [:div]
        isearch = make_isearch_form
        content.push(isearch)
        code = markup_source
        content.push([:pre, *code])
      end
      return content
    end

    def make_not_found
      sprintf(_("No contents were found matching %s"), 
              @path)
    end

    def gzip(string)
      strio = StringIO.new
      writer = Zlib::GzipWriter.new(strio)
      writer.print(string)
      writer.finish
      return strio.string
    end

    def set_response(html)
      set_content_type_text_html
      body = format_html(html)
      if @request.gzip_encoding_supported?
        @response["Content-Encoding"] = "gzip"
        @response.body = gzip(body)
      else
        @response.body = body
      end
    end

    def choose_method
      method = :make_not_found
      if @path.empty?
        method = :list_packages
        title = make_title(_("List of Packages"))
        status_title = _("List of Packages")
      else
        @path_id = @dbm.get_path_id(@path)
        @package_name = @path.split("/").first
        if @path_id 
          method = :markup_file 
        elsif @dbm.has_package?(@package_name)
          method = :list_files 
        end
        title = make_title(@path)
        status_title = make_breadcrumbs(@path)
      end
      return method, title, status_title
    end

    def do_GET(request, response)
      init_servlet(request, response)
      log(@path)

      @path = make_path
      @to = nil
      @total = nil

      method, title, status_title = choose_method

      html = make_html
      head = [:head, title, make_script, *make_meta_and_css]
      body = [:body, {:onload => "initCache();",
                      :onclick => "clearHighlight();" }]
      body.push(make_h1)
      body.push(make_search_form)
      content = self.send(method)

      status_line = make_status_line(status_title, method)
      body.push(status_line)
      body.push(content)
      body.push(make_footer)

      html.push(head)
      html.push(body)
      set_response(html)
    end

    GonzuiServlet.register(self)
  end
end
