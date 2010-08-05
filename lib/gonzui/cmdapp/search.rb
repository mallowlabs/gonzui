#
# search.rb - command line searcher
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  class CommandLineSearcher
    def initialize(config, options)
      @config = config
      @dbm = DBM.open(@config, true)
      @out = (options['out'] or STDOUT)
      @nlines  = options['line-number']

      @show_method = if options['context']
                       :show_context_lines 
                     elsif options['count']
                        :show_count
                     else
                        :show_line
                     end

      @package_name = options['package']

      @ncontexts = options['context'].to_i

      @search_method = :find_all
      @search_method = :find_all_by_prefix if options['prefix']
      @search_method = :find_all_by_regexp if options['regexp']

      @use_regexp  = options['regexp']
      @use_color   = options['color']
      @no_filename = options['no-filename']

      @target_type = :all
      if options['type']
        type = options['type'].intern
        eprintf("unknown type: #{type}") unless LangScan::Type.include?(type)
        @target_type = type
      end
    end

    private
    def highlight(string, start_tag = "\x1b[01;31m", end_tag = "\x1b[00m")
      sprintf("%s%s%s", start_tag, string, end_tag)
    end

    def show_line(content, path, regexp, info)
      range = content.line_range(info.byteno)
      filename = if @no_filename then "" else path + ":" end
      linemark = if @nlines then info.lineno.to_s + ":" else "" end
      word = @dbm.get_word(info.word_id)
      pre = content.substring(range.first...info.byteno)
      post = content.substring((info.byteno + word.length)...range.last)
      mid = word
      mid = highlight(mid) if @use_color
      @out.printf("%s%s%s%s%s\n", filename, linemark, pre, mid, post)
    end

    def show_context_lines(content, path, regexp, info)
      @out.printf("== %s\n", path) unless @no_filename
      content.each_line_range(info.byteno, @ncontexts) {|lineno_offset, range|
        lineno = info.lineno + lineno_offset
        linemark = if @nlines 
                     mark = if lineno == info.lineno then ":" else "-" end
                     lineno.to_s + mark
                   else 
                     "" 
                   end
        if range.include?(info.byteno)
          word = @dbm.get_word(info.word_id)
          pre = content.substring(range.first...info.byteno)
          post_range = (info.byteno + word.length)...range.last
          post = content.substring(post_range)
          mid = word
          mid = highlight(mid) if @use_color
          @out.printf("%s%s%s%s\n", linemark, pre, mid, post)
        else
          @out.printf("%s%s\n", linemark, content.substring(range))
        end
      }
    end

    def show_result(regexp, info)
      content = @dbm.get_content(info.path_id)
      path = @dbm.get_path(info.path_id)
      send(@show_method, content, path, regexp, info)
    end

    def package_match?(target_package_id, info)
      package_id = @dbm.get_package_id_from_path_id(info.path_id)
      return target_package_id == package_id
    end

    public
    def search(pattern)
      separator = ""
      regexp = if @use_regexp
                Regexp.new(pattern)
              else
                Regexp.new(Regexp.quote(pattern))
              end
      results = @dbm.send(@search_method, pattern)
      prev_lineno = prev_path_id = nil
      target_package_id = @dbm.get_package_id(@package_name) if @package_name
      results.sort_by {|x| [x.path_id, x.byteno] }.each {|info|
        next if prev_lineno and prev_path_id and 
          info.path_id == prev_path_id and
          info.lineno == prev_lineno
        if info.match?(@target_type)
          unless @show_method == :show_count
            if @package_name.nil? or package_match?(target_package_id, info)
              @out.print separator
              show_result(regexp, info)
              separator = "\n" if @show_method == :show_context_lines
            end
          end
        end
        prev_lineno = info.lineno
        prev_path_id = info.path_id
      }
      puts results.length if @show_method == :show_count
    end

    def finish
      @dbm.close
    end
  end
end
