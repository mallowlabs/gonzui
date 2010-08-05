#
# searchquery.rb - search query implementation
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  QueryItem = Struct.new(:property, :value, :phrase_p)
  class QueryItem
    def to_s
      string = ""
      string << self.property.to_s << ":" if self.property
      if phrase?
        string << sprintf('"%s"', self.value.join(" "))
      else
        string << self.value
      end
      return string
    end

    def phrase?
      self.phrase_p == true
    end
  end

  class SearchQuery
    include Enumerable
    include GetText

    def initialize(config, query_string, options = {})
      @query_string = query_string
      @options = options
      @items = []

      @package = nil
      @path = nil
      @format = nil
      @license = nil
      @error = nil

      @words = []
      @ignored_words = []

      @max_words = config.max_words
      @nwords = 0
      parse_query_string
    end
    attr_accessor :path
    attr_reader :package
    attr_reader :format
    attr_reader :license
    attr_reader :ignored_words
    attr_reader :words
    attr_reader :options

    private
    KnownProperties = []
    [:path, :package].each {|property|
      KnownProperties.push(property)
    }
    # :fundef, :funcall, etc.
    LangScan::Type.each_group {|group|
      group.each {|type_info|
        KnownProperties.push(type_info.type)
      }
    }

    def parse_query_string
      kp = KnownProperties.join("|")
      parts = @query_string.scan(/((?:#{kp}):)?(?:"(.+)"|(\S+))/)
      parts.each {|prefix, quoted, bare|
        phrase_p = if quoted then true else false end
        text = (quoted or bare)
        if prefix
          property = prefix.chop.intern
          case property
          when :package
            @error = QueryError.new(N_("package: duplicated.")) if @package
            @package = text
          when :path
            @error = QueryError.new(N_("path: duplicated.")) if @path
            @path = text
          else
            add_item(property, text, phrase_p)
          end
        else
          add_item(nil, text, phrase_p)
        end
      }
      @format = @options[:format]
      @license = @options[:license]
      if @package and @path
        message = N_("package: and path: cannot be specified together.")
        @error = QueryError.new(message)
      end
      make_words
    end

    def make_words
      @words = @items.map {|i| i.value }.flatten
    end

    def add_item_for_phrase(property, text)
      value = []
      TextTokenizer.each_word(text) {|word, unused|
        if @nwords < @max_words
          @nwords += 1
          value.push(word)
        else
          @ignored_words.push(word)
        end
      }
      unless value.empty?
        item = QueryItem.new(property, value, true)
        @items.push(item)
      end
    end

    def add_item_for_single_word(property, text)
      if @nwords < @max_words
        @nwords += 1
        item = QueryItem.new(property, text, false)
        @items.push(item)
      else
        @ignored_words.push(text)
      end
    end

    def add_item(property, text, phrase_p)
      if phrase_p or has_multi_byte_char?(text)
        add_item_for_phrase(property, text)
      else
        add_item_for_single_word(property, text)
      end
    end

    def has_multi_byte_char?(text)
      /[^\x00-\x7f]/u.match(text)
    end

    def reset
      @ignored_words = []
      @items = []
      @nwords = 0
    end

    public
    def path_only?
      @items.empty? and @path and @package.nil?
    end

    def package_only?
      @items.empty? and @path.nil? and @package
    end

    def string
      @query_string
    end

    def simplified_string
      @items.map {|item| item.to_s }.join(" ")
    end

    def string_without_properties
      @items.map {|item| item.value.to_s }.join(" ")
    end

    def empty?
      @items.empty? and @package.nil? and @path.nil?
    end

    def first
      @items.first
    end

    def last
      @items.last
    end

    def each
      @items.each {|item| yield(item) }
    end

    def length
      @items.length
    end

    def collect
      @items.find_all {|item| 
        if block_given?
          yield(item)
        else
          true
        end
      }.map {|item| 
        item.value
      }
    end

    def keywords
      collect {|item| not item.phrase? }
    end

    def phrases
      collect {|item| item.phrase? }
    end

    def tokenize_all
      original_items = @items.clone
      original_nwords = @nwords
      reset
      original_items.each {|item|
        if item.phrase?
          value = item.value.join(" ")
          add_item_for_phrase(item.property, value)
        else
          add_item_for_phrase(item.property, item.value)
        end
      }
      make_words

      modified = if @nwords != original_nwords then true else false end
      return modified
    end

    def validate
      raise @error if @error
    end
  end
end
