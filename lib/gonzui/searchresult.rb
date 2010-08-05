#
# searchresult.rb - search result implementation
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  class SearchResult 
    include Enumerable

    def initialize
      @items = []
      @limit_exceeded = false
    end
    attr_accessor :limit_exceeded

    public
    def [] (i)
      @items[i]
    end

    def clear
      @items.clear
    end

    def each
      @items.each {|item| yield(item) }
    end

    def each_from(from)
      (from...@items.length).each {|i|
        yield(@items[i])
      }
    end

    def empty?
      @items.empty?
    end

    def first
      @items.first
    end

    def last
      @items.last
    end

    def length
      @items.length
    end
    alias :nhits :length

    def limit_exceeded?
      @limit_exceeded
    end

    def push(item)
      @items.push(item)
    end

    def single?
      @items.length == 1 and not @items.first.has_more?
    end

    def single_path?
      @items.length == 1 and @items.first.has_more_in_path?
    end
  end

  class ResultItem
    def initialize(package_id, path_id)
      @package_id = package_id
      @path_id = path_id
      @list = []
      @grouped_by = nil
    end
    attr_reader :package_id
    attr_reader :path_id
    attr_reader :list

    public
    def push(occ)
      @list.push(occ)
    end

    def has_more?
      not @grouped_by.nil?
    end

    def has_more_in_package?
      @grouped_by == :package
    end

    def has_more_in_path?
      @grouped_by == :path
    end

    def has_more_in_package
      @grouped_by = :package
    end

    def has_more_in_path
      @grouped_by = :path
    end
  end
end
