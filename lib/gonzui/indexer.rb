#
# indexer.rb - indexer implementation
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

require 'ftools'
require 'digest/md5'
require 'langscan'

module Gonzui
  class IndexerError < GonzuiError; end
  
  class Indexer
    include Util

    @@performance_monitor = PerformanceMonitor.new

    def self.statistics 
      return "" if @@performance_monitor.empty?
      pm = @@performance_monitor
      summary = "Performance statistics:\n"
      summary << pm.heading
      summary << pm.format([Indexer, :index],
                           [Indexer, :read_content],
                           [Indexer, :add_license],
                           [Indexer, :index_content])
      labels = LangScan.modules.map {|m|
        [m, :scan]
      }.push([Indexer, :add_fragment],
             [Indexer, :flush_cache])
      summary << pm.format([Indexer, :index_content], *labels)
      return summary
    end

    def initialize(config, dbm, source_uri, normalized_path, content, 
                   options = {})
      @config = config
      @dbm = dbm
      @normalized_path = normalized_path
      @source_uri = source_uri
      @content = content
      @content_hash = Digest::MD5.hexdigest(content.text)
      @noindex_formats = (options[:noindex_formats] or @config.noindex_formats)

      @package_name = get_package_name
      @seqno      = 0

      @word_cache = {}
      @wordinfo_cache = {}
      @digest_cache = []

      # to be initialized
      @format_id  = nil
      @license_id = nil
      @license_abbrev = nil
      @encoding = nil
      @nlines = nil
      @package_id = nil
      @path_id = nil
      @bols = [] # positions of beginning of lines
      @indexed_p = false

      initialize_profilers_if_necessary
    end

    def initialize_profilers_if_necessary
      # profiler
      if @config.verbose
        @@performance_monitor.profile(Indexer, :index)
        @@performance_monitor.profile(Indexer, :read_content)
        @@performance_monitor.profile(Indexer, :index_content)
        @@performance_monitor.profile(Indexer, :add_fragment)
        @@performance_monitor.profile(Indexer, :add_license)
        @@performance_monitor.profile(Indexer, :flush_cache)
      end
    end

    def read_content
      content, @encoding = normalize_content(@content.text)
      @content.text = content
      @nlines = 0
      pos = 0
      @content.text.each_line {|line| 
        @bols.push(pos)
        @nlines += 1
        pos += line.length
      }
    end

    # allow 0x09 (TAB), 0x0a (LF), 0x0c(^L), 0x0d (CR) 0x1b (ESC)
    allowed = [0x09, 0x0a, 0x0c, 0x0d, 0x1b]
    pattern = "["
    pattern << (0...0x20).find_all {|x|
      not allowed.include?(x)
    }.map {|x| sprintf("\\x%02x", x) }.join 
    pattern << "]"
    BinaryRegexp = Regexp.new(pattern)

    def binary_content?(content)
      BinaryRegexp.match(content)
    end

    def convert_to_utf8(content)
      encoding = "ascii"
      if binary_content?(content)
        encoding = "binary"
      else 
        if @config.utf8
          content, encoding = UTF8.to_utf8(content)
        end
      end
      return content, encoding
    end

    def normalize_content(content)
      content, encoding = convert_to_utf8(content)
      unless encoding == "binary"
        content = content.untabify
        content.gsub!(/\r\n?/, "\n")
      end
      return content, encoding
    end

    def get_package_name
      parts = @normalized_path.split("/")
      if parts.length < 2
        raise IndexerError.new("normalized path should not be flat")
      end
      package_name = parts.first
      if package_name.size == 0 || package_name == "." || package_name == ".."
        package_name = File.basename(@source_uri.path)
      end
      return package_name
    end

    def add_text(fragment, type_id)
      text = fragment.text
      byteno = fragment.byteno
      TextTokenizer.each_word(text) {|word, pos|
        add_word(word, byteno + pos, type_id)
      }
    end

    def add_fragment(fragment)
      type_id = @dbm.get_type_id(fragment.type)
      if LangScan::Type.splittable?(fragment.type)
        add_text(fragment, type_id)
      else
        add_word(fragment.text, fragment.byteno, type_id)
      end

      @digest_cache.push(fragment.byteno, fragment.text.length, type_id)
    end

    def flush_cache
      all_word_ids = @wordinfo_cache.keys.sort!
      all_word_ids.each {|word_id|
        path_word_id = AutoPack.pack_id2(@path_id, word_id)
        @dbm.pathwordid_info[path_word_id] = 
          DeltaDumper.dump_tuples(WordInfo, @wordinfo_cache[word_id])
      }
      @dbm.put_pathid_wordids(@package_id, @path_id, all_word_ids)
      @dbm.pathid_wordids[@path_id] = DeltaDumper.dump_ids(all_word_ids)
      @dbm.pathid_digest[@path_id] = 
        DeltaDumper.dump_tuples(DigestInfo, @digest_cache)
      @dbm.pathid_bols[@path_id] = DeltaDumper.dump_fixnums(@bols)
      @wordinfo_cache.clear
      @dbm.word_id_counter.flush
    end

    def add_property(abbrev, name, counter, make_key, pkgid_ids)
      id = @dbm.send(counter).get_id2(abbrev, name)
      @dbm.send(pkgid_ids)[@package_id] = id
      @dbm.increase_counter(@dbm.send(make_key, abbrev))
      return id
    end

    def add_format(format_abbrev, format_name)
      @format_id = add_property(format_abbrev, 
                                format_name,
                                :format_id_counter,
                                :make_ncontents_by_format_key,
                                :pkgid_fmtids)
    end

    def add_license
      detector = LicenseDetector.new(@content.text)
      license = detector.detect
      @license_id = add_property(license.abbrev, 
                                 license.name,
                                 :license_id_counter,
                                 :make_ncontents_by_license_key,
                                 :pkgid_lcsids)
      @license_abbrev = license.abbrev
    end

    def add_path
      assert_equal(false, @dbm.path_pathid.include?(@normalized_path))
      @path_id = @dbm.path_id_counter.make_new_id
      @dbm.path_pathid[@normalized_path] = @path_id
      @dbm.pathid_path[@path_id] = @normalized_path
      @dbm.pkgid_pathids[@package_id] = @path_id
    end

    def get_fragments(scanner)
      @@performance_monitor.profile(scanner, :scan) if @config.verbose
      fragments = []
      scanner.scan(@content.text) {|fragment|
        fragments.push(fragment) if LangScan::Type.include?(fragment.type)
      }
      fragments = fragments.sort_by {|fragment| fragment.byteno }
      return fragments
    end

    def add_word(word, byteno, type_id)
      word_id = @dbm.word_id_counter.get_id(word)
      array = (@wordinfo_cache[word_id] ||= [])
      array.push(@seqno, byteno, type_id)
      @seqno += 1
    end

    def add_package_if_necessary
      if @dbm.has_package?(@package_name)
        @package_id = @dbm.get_package_id(@package_name)
      else
        @package_id = @dbm.package_id_counter.make_new_id
        @dbm.pkg_pkgid[@package_name] = @package_id
        @dbm.pkgid_pkg[@package_id] = @package_name
        @dbm.pkgid_src[@package_id] = @source_uri.to_s
        @dbm.put_package_options(@package_id)
      end
    end

    def make_content_info
      ContentInfo.dump(@content.length, @content.mtime.to_i,
                       Time.now.to_i, @format_id, @license_id,
                       @nlines, @indexed_p)
    end

    def index_content(scanner)
      fragments = []
      begin
        fragments = get_fragments(scanner)
      rescue 
        # fallback to the text scanner
        unless scanner == LangScan::Text
          vprintf("#{@normalized_path}: fallback to LangScan::Text")
          scanner = LangScan::Text
          retry
        end
      end
      fragments.each {|fragment| add_fragment(fragment) }
      flush_cache
      @dbm.increase_counter(:ncontents_indexed)
      @dbm.increase_counter(:nlines_indexed, @nlines)
      @indexed_p = true
    end

    def add_content_common(format_abbrev, format_name)
      add_format(format_abbrev, format_name)
      add_license
      @dbm.pathid_pkgid[@path_id] = @package_id
      @dbm.pathid_content[@path_id] = @content.text
      @dbm.pathid_info[@path_id] = make_content_info
      @dbm.pathid_hash[@path_id] = @content_hash
      vprintf("added (%s): %s (%s)", format_abbrev, 
              @normalized_path, @license_abbrev)
    end

    def add_binary_content
      add_content_common("binary", "Binary")
    end

    def make_scanner
      scanner = LangScan.choose(@normalized_path, @content.text)
      scanner = LangScan::Text if scanner.nil?
      return scanner
    end

    def indexable?(scanner)
      not @noindex_formats.include?(scanner.abbrev)
    end

    def add_content_with_indexing
      scanner = make_scanner
      if indexable?(scanner)
        index_content(scanner)
      else
        vprintf("skip indexing: %s", @normalized_path)
      end
      add_content_common(scanner.abbrev, scanner.name)
    end

    def add_content
      if @encoding == "binary"
        add_binary_content
      else
        add_content_with_indexing
      end
    end

    public
    def index
      read_content
      add_package_if_necessary
      add_path
      add_content
    end
  end
end
