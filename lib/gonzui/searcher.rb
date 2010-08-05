#
# searcher.rb - searcher implementation
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  # FIXME: It's not efficient. It's better to use a data
  # structure like a priority queue to handle the
  # list-of-list to achieve better performance.
  class PhraseFinder
    include Util

    def initialize(dbm, path_id, words)
      @word_ids = []
      @list_of_list = []

      words.each {|word|
        word_id = dbm.get_word_id(word)
        assert_non_nil(word_id)
        info_list = dbm.get_all_word_info(path_id, word_id)
        @word_ids.push(word_id)
        @list_of_list.push(info_list)
      }
      @last_word = words.last
    end

    def match?(info_list, i)
      j = 0
      prev_seqno = nil
      @word_ids.each {|word_id|
        return false unless i + j < info_list.length
        info = info_list[i + j]
        return false unless word_id == info.word_id
        return false unless prev_seqno.nil? or (prev_seqno + 1) == info.seqno
        prev_seqno = info.seqno
        j += 1
      }
      return true
    end

    public
    def each
      prev = nil
      info_list = @list_of_list.flatten.sort_by {|info| 
        info.seqno
      }.find_all {|info|
        v = info.seqno != prev
        prev = info.seqno
        v
      }
      info_list.length.times {|i|
        if match?(info_list, i)
          first = info_list[i]
          last = info_list[i + @word_ids.length - 1]
          length = last.byteno + @last_word.length - first.byteno
          occ = Occurrence.new(first.byteno, first.lineno, length)
          yield(occ)
        end
      }
    end
  end

  class QueryError < GonzuiError; end
  class NotFoundError < GonzuiError; end

  class Searcher
    include Util

    def initialize(dbm, search_query, at_most_nresults)
      @dbm = dbm
      @search_query = search_query
      @at_most_nresults = at_most_nresults
      # If "all" is specified, both IDs become nil. No problem.
      @target_format_id = @dbm.get_format_id(@search_query.format)
      @target_license_id = @dbm.get_license_id(@search_query.license)
    end

    def find_word_id(word)
      word_id = @dbm.get_word_id(word)
      raise NotFoundError.new unless word_id
      return word_id
    end

    def find_package_id(package_name)
      package_id = @dbm.get_package_id(package_name)
      raise NotFoundError.new unless package_id
      return package_id
    end

    def find_package_id_from_path_id(path_id)
      package_id = @dbm.get_package_id_from_path_id(path_id)
      assert_non_nil(package_id)
      return package_id
    end

    def filter_package_ids_by_property(package_ids, target_id, get_ids)
      if target_id
        package_ids = package_ids.find_all {|package_id|
          format_ids = @dbm.send(get_ids, package_id)
          format_ids.include?(target_id)
        }
      end
      return package_ids
    end

    def filter_package_ids_by_format(package_ids)
      filter_package_ids_by_property(package_ids, @target_format_id, 
                                     :get_format_ids_from_package_id)
    end

    def filter_package_ids_by_license(package_ids)
      filter_package_ids_by_property(package_ids, @target_license_id, 
                                     :get_license_ids_from_package_id)
    end

    def filter_package_ids(package_ids)
      package_ids = filter_package_ids_by_format(package_ids)
      package_ids = filter_package_ids_by_license(package_ids)
      return package_ids
    end

    def filter_path_ids_by_property(path_ids, target_id, get_id)
      if target_id
        path_ids = path_ids.find_all {|path_id|
          format_id = @dbm.send(get_id, path_id)
          format_id == target_id
        }
      end
      return path_ids
    end
    
    def filter_path_ids_by_format(path_ids)
      filter_path_ids_by_property(path_ids, @target_format_id, 
                                  :get_format_id_from_path_id)
    end

    def filter_path_ids_by_license(path_ids)
      filter_path_ids_by_property(path_ids, @target_license_id, 
                                  :get_license_id_from_path_id)
    end

    def filter_path_ids(path_ids)
      path_ids = filter_path_ids_by_format(path_ids)
      path_ids = filter_path_ids_by_license(path_ids)
      return path_ids
    end

    def find_ids(get_proc, filter_proc)
      ids = nil
      @search_query.words.each {|word|
        word_id = find_word_id(word)
        tmp = get_proc.call(word_id)
        tmp = filter_proc.call(tmp)
        ids = if ids.nil? then tmp else ids & tmp end
        break if ids.empty?
      }
      raise NotFoundError.new if ids.nil?
      return ids
    end

    def find_package_ids
      get_proc = lambda {|word_id| @dbm.get_package_ids(word_id) }
      filter_proc = lambda {|ids| filter_package_ids(ids) }
      return find_ids(get_proc, filter_proc)
    end

    def find_path_id(path)
      path_id = @dbm.get_path_id(path)
      raise NotFoundError.new unless path_id
      return path_id
    end

    def find_path_ids(package_id)
      get_proc = lambda {|word_id| 
        @dbm.get_path_ids_from_package_and_word_id(package_id, word_id)
      }
      filter_proc = lambda {|ids| filter_path_ids(ids) }
      return find_ids(get_proc, filter_proc)
    end

    def match_target?(info, property)
      if property
        return info.match?(property)
      else
        return true
      end
    end

    def break_needed?(option)
      judge = false
      case option
      when :all, :find_one_extra
      when :exact
        judge = true
      else
        assert_not_reached
      end
      return judge
    end

    # FIXME: It's too complicated
    def get_result_item(path_id, option)
      package_id = @dbm.get_package_id_from_path_id(path_id)
      item = ResultItem.new(package_id, path_id)
      @search_query.each {|qitem|
        nfound = 0
        if qitem.phrase?
          finder = PhraseFinder.new(@dbm, path_id, qitem.value)
          finder.each {|occ|
            if option == :find_one_extra and nfound >= 1
              item.has_more_in_path
              break
            end
            item.push(occ)
            nfound += 1
            break if break_needed?(option)
          }
        else
          word_id = find_word_id(qitem.value)
          @dbm.find_word_info(path_id, word_id) {|info|
            next unless match_target?(info, qitem.property)
            occ = Occurrence.new(info.byteno, info.lineno, qitem.value.length)
            if option == :find_one_extra and nfound >= 1
              item.has_more_in_path
              break
            end
            item.push(occ)
            nfound += 1
            break if break_needed?(option)
          }
        end
        return nil if nfound == 0
      }
      return item
    end

    def search_with_path_internal(path_id)
      result = SearchResult.new
      item = get_result_item(path_id, :all)
      raise NotFoundError.new if item.nil?
      item.has_more_in_path if item.list.length > @search_query.length
      result.push(item)
      return result
    end

    def search_with_path
      path_id = find_path_id(@search_query.path)
      return search_with_path_internal(path_id)
    end

    def search_with_package_internal(package_id)
      result = SearchResult.new
      path_ids = find_path_ids(package_id)
      path_ids.each {|path_id|
        item = get_result_item(path_id, :find_one_extra)
        next if item.nil?
        result.push(item)
        if result.length >= @at_most_nresults
          result.limit_exceeded = true
          break
        end
      }
      if result.length == 1 and result.first.has_more?
        return search_with_path_internal(result.first.path_id)
      else
        return result
      end
    end

    def search_with_package
      package_id = find_package_id(@search_query.package)
      return search_with_package_internal(package_id)
    end

    def search_without_scope
      result = SearchResult.new
      package_ids = find_package_ids
      package_ids.each {|package_id|
        list = []
        path_ids = find_path_ids(package_id)
        path_ids.each {|path_id|
          item = get_result_item(path_id, :find_one_extra)
          next if item.nil?
          list.push(item)
          break if list.length >= 2
        }
        next if list.empty?
        item = list.first
        item.has_more_in_package if list.length > 1
        result.push(item)
        if result.length >= @at_most_nresults
          result.limit_exceeded = true
          break
        end
      }
      if result.length == 1
        return search_with_package_internal(result.first.package_id)
      else
        return result
      end
    end

    public
    def search
      retried = false
      begin
        result = if @search_query.path
                   search_with_path
                 elsif @search_query.package
                   search_with_package
                 else
                   search_without_scope
                 end
        return result
      rescue NotFoundError
        if retried == false and @search_query.tokenize_all
          retried = true
          retry
        end
        return SearchResult.new
      end
    end
  end
end
