#
# uri.rb - uri functions
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  QueryValue = Struct.new(:short_name, :default_value, :conversion_method)

  module URIMaker
    ParamTable = {
      :display_language      => QueryValue.new("dl", nil,   :to_s),
      :from                  => QueryValue.new("f",  0,     :to_i),
      :format                => QueryValue.new("fm", "all",  :to_s),
      :grep_pattern          => QueryValue.new("g",  nil,   :to_s),
      :license               => QueryValue.new("l",  "all",  :to_s),
      :nresults_per_page     => QueryValue.new("n",  10,    :to_i),
      :phrase_query          => QueryValue.new("pq", nil,   :to_s),
      :basic_query           => QueryValue.new("q",  "",    :to_s),
      :target_type           => QueryValue.new("tt", nil,   :to_s),
    }

    def decompose_search_query(search_query)
      options = {}
      options[:basic_query] = search_query.string
      options[:format] = search_query.format
      options[:license] = search_query.license
      return options
    end

    def get_default_query_value(long_name)
      ParamTable[long_name]
    end

    def get_query_value(query, long_name)
      qv = get_default_query_value(long_name)
      assert(qv)
      value = query[qv.short_name]
      if value and not value.empty?
        return value.send(qv.conversion_method)
      else
        return qv.default_value
      end
    end

    def get_short_name(long_name)
      qv = ParamTable[long_name]
      raise "unknown variable name" if qv.nil?
      return qv.short_name
    end

    def make_advanced_search_uri(search_query)
      make_uri_general(AdvancedSearchServlet)
    end

    def make_doc_uri(path = nil)
      make_uri_general(FileHandler, path)
    end

    def make_google_uri(search_query)
      sprintf("http://www.google.com/search?q=%s", 
              HTTPUtils.escape_form(search_query.string_without_properties))
    end

    def make_lineno_uri(markup_uri, lineno)
      sprintf("%s#l%d", markup_uri, lineno)
    end

    def make_markup_uri(path = "", search_query = nil, options = {})
      if search_query
        decompose_search_query(search_query).each {|k, v|
          options[k] = v
        }
      end
      return make_uri_with_options(MarkupServlet, path, options)
    end

    def make_search_uri(search_query, options = {})
      options.merge!(decompose_search_query(search_query))
      make_uri_with_options(SearchServlet, "", options)
    end

    def make_search_uri_partial(query_string)
      sprintf("%s?%s=", 
              make_uri_general(SearchServlet),
              get_short_name(:basic_query))
    end

    def make_source_uri(path = nil)
      make_uri_general(SourceServlet, path)
    end

    def make_stat_uri(path = nil)
      make_uri_general(StatisticsServlet, path)
    end

    def make_top_uri
      make_uri_general(TopPageServlet)
    end

    def escape_path(path)
      path.gsub(%r{[^A-Za-z0-9\-._~!$&'()*+,;=:@/]}) {
        '%' + $&.unpack("H2")[0].upcase
      }
    end

    def make_uri_general(klass, path = nil)
      assert_non_nil(@config)
      if path
        return URI.path_join(@config.base_mount_point,
                             klass.mount_point,
                             escape_path(path))
      else
        return URI.path_join(@config.base_mount_point, klass.mount_point)
      end
    end

    def make_uri_with_options(klass, path, options)
      params = []
      options.each {|name, value|
        next if value.nil?
        qv = get_default_query_value(name)
        if qv and value != qv.default_value
          param = sprintf("%s=%s", qv.short_name, HTTPUtils.escape_form(value.to_s))
          params.push(param)
        end
      }
      assert_non_nil(@config)
      uri = URI.path_join(@config.base_mount_point, klass.mount_point)
      uri = URI.path_join(uri, escape_path(path)) unless path.empty?
      uri << "?" + params.join("&") unless params.empty?
      return uri
    end
  end
end
