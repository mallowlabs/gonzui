#
# snippet.rb - snippet implementation
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  class SnippetMaker
    include URIMaker

    def initialize(content, result_item, link_uri = nil)
      @content = content
      @result_item = result_item
      @link_uri = link_uri

      # FIXME: should be customizable?
      @ncontexts = 1
    end

    private
    def make_emphasized_line(lineno, line_range, *occ_list)
      line = [:span]
      occ_list.each {|occ|
        occ_range = (occ.byteno ... (occ.byteno + occ.length))
        pre = range = nil
        if line_range.include?(occ.byteno)
          pre = @content.substring(line_range.first...occ.byteno)
          range = (occ.byteno ... [occ_range.last, line_range.last].min)
        elsif occ_range.include?(line_range.first)
          range = (line_range.first ... [occ_range.last, line_range.last].min)
        end
        line.push(pre) if pre
        if range
          text = @content[range]
          line.push([:strong, text])
          line_range = (range.last ... line_range.last)
        end
      }
      remaining = @content.substring(line_range)
      line.push(remaining)
      return line
    end

    def make_occurrences_by_lineno
      occurrences_by_lineno = {}
      @result_item.list.sort_by {|occ| occ.byteno}.each {|occ|
        occurrences_by_lineno[occ.lineno] ||= []
        occurrences_by_lineno[occ.lineno].push(occ)
      }
      return occurrences_by_lineno
    end

    def add_contexts(lines_with_lineno, occ)
      @content.each_line_range(occ.byteno, @ncontexts) {|lineno_offset, range|
        lineno = occ.lineno + lineno_offset
        line = @content.substring(range)
        lines_with_lineno.push([line, lineno]) unless lineno == occ.lineno
      }
      return lines_with_lineno.sort_by {|line, lineno| lineno }
    end

    def make_kwic_single
      lines_with_lineno = []
      occ = @result_item.list.first
      text = @content[occ.byteno, occ.length]
      @content.each_line_range(occ.byteno, @ncontexts) {|lineno_offset, range|
        lineno = occ.lineno + lineno_offset
        line = make_emphasized_line(lineno, range, occ)
        lines_with_lineno.push([line, lineno])
      }
      return lines_with_lineno
    end

    def make_kwic_multi
      seen = {}
      lines_with_lineno = []
      occurrences_by_lineno = make_occurrences_by_lineno
      occurrences_by_lineno.keys.sort.each {|lineno|
        occ_list = occurrences_by_lineno[lineno]
        range = @content.line_range(occ_list.first.byteno)
        line = make_emphasized_line(lineno, range, *occ_list)
        lines_with_lineno.push([line, lineno])
      }
      if occurrences_by_lineno.length == 1
        occ = @result_item.list.first
        lines_with_lineno = add_contexts(lines_with_lineno, occ)
      end
      return lines_with_lineno
    end

    def make_kwic
      if @result_item.list.length == 1
        return make_kwic_single
      else
        return make_kwic_multi
      end
    end

    def collect_context_lines
      context_lines = {}

      occurrences_by_lineno = make_occurrences_by_lineno
      occurrences_by_lineno.keys.sort.each {|lineno|
        occ_list = occurrences_by_lineno[lineno]
        range = @content.line_range(occ_list.first.byteno)
        occ = occ_list.first
        @content.each_line_range(occ.byteno, @ncontexts) {|lineno_offset,range|
          lineno = occ.lineno + lineno_offset
          next if context_lines.has_key?(lineno) and lineno_offset != 0
          line = make_emphasized_line(lineno, range, *occ_list)
          context_lines[lineno] = line
        }
      }
      return context_lines
    end

    def make_separator
      [:div, {:class => "separator"}, ""]
    end

    public
    def make_line_oriented_kwic
      lines_with_lineno = make_kwic
      pre = [:pre, {:class => "lines"}]
      lines_with_lineno.sort_by {|line, lineno|
        lineno
      }.each {|line, lineno|
        lineno_uri = make_lineno_uri(@link_uri, lineno)
        lineno_mark = [:a, {:href => lineno_uri}, lineno.to_s + ": "]
        pre.push(lineno_mark, line)
        pre.push("\n")
      }
      return pre
    end

    def make_context_grep
      context_lines = collect_context_lines
      pre = [:pre, {:class => "lines"}]
      prev_lineno = nil
      context_lines.keys.sort.each {|lineno|
        lineno_uri = make_lineno_uri(@link_uri, lineno)
        lineno_mark = [:a, {:href => lineno_uri }, lineno.to_s + ": "]
        pre.push(make_separator)if prev_lineno and lineno > prev_lineno + 1
        pre.push(lineno_mark, context_lines[lineno], "\n")
        prev_lineno = lineno
      }
      return pre
    end
  end
end
