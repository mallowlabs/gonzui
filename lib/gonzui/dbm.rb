#
# dbm.rb - gonzui DB library
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#
require 'zlib'

module Gonzui
  class IncompatibleDBError < GonzuiError; end
  DB_VERSION = "13"

  module DBM
    module_function
    def open(config, read_only = false)
      File.mkpath(config.db_directory) unless read_only

      dbm_class = BDBDBM # to be pluggable
      dbm = dbm_class.new(config, read_only)
      if block_given?
        begin
          yield(dbm)
        ensure
          dbm.close
        end
      else
        return dbm
      end
    end
  end

  class IDCounter
    def initialize(dbm, id_name, counter, db, rev_db, alt_db)
      @dbm     = dbm
      @id_name = id_name
      @counter = counter
      @db      = dbm.send(db)
      @rev_db  = dbm.send(rev_db)
      @alt_db  = if alt_db then dbm.send(alt_db) else nil end

      @count = 0
      @cache = {}
      @last_id = (@dbm.seq[make_last_key] or -1)
    end

    def flush
      if @count > 0
        @dbm.increase_counter(@counter, @count)
        @dbm.seq[make_last_key] = @last_id if @last_id >= 0
        @count = 0
        @cache = {}
      end
    end

    def make_last_key
      "last_" + @id_name.to_s
    end

    def make_new_id
      @count += 1
      @last_id += 1
      return @last_id
    end

    def get_id(text)
      id = @cache[text]
      if id.nil?
        id = @db[text]
        if id.nil?
          id = make_new_id
          @db[text] = id
          @rev_db[id] = text
        end
        @cache[text] = id
      end
      return id
    end

    def get_id2(text, alt)
      id = @cache[text]
      if id.nil?
        id = @db[text]
        if id.nil?
          id = make_new_id
          @db[text] = id
          @rev_db[id] = text
          @alt_db[id] = alt
        end
        @cache[text] = id
      end
      return id
    end
  end

  module AutoPack
    Adaptor  = Struct.new(:store, :fetch)
    ID       = Adaptor.new(lambda {|id|  pack_id(id) },
                           lambda {|str| unpack_id(str) })
    Fixnum   = Adaptor.new(lambda {|id|  pack_fixnum(id) },
                           lambda {|str| unpack_fixnum(str) })
    Symbol   = Adaptor.new(lambda {|sym| sym.to_s},
                           lambda {|str| str.intern})
    String   = Adaptor.new(nil, nil)
    GZString = Adaptor.new(lambda {|str| Zlib::Deflate.deflate(str) },
                           lambda {|str| Zlib::Inflate.inflate(str) })
  end

  class DBMError < GonzuiError; end
  class AbstractDBM
    include Util

    ap = AutoPack # for short
    DBTable = [ 
      [:fmtid_fmt,         ap::ID,     ap::String,   false],
      [:fmtid_fabbr,       ap::ID,     ap::String,   false],
      [:fabbr_fmtid,       ap::String, ap::ID,       false],
      [:lcsid_lcs,         ap::ID,     ap::String,   false],
      [:lcsid_labbr,       ap::ID,     ap::String,   false],
      [:labbr_lcsid,       ap::String, ap::ID,       false],
      [:seq,               ap::String, ap::Fixnum,   false],
      [:stat,              ap::String, ap::Fixnum,   false],
      [:pkg_pkgid,         ap::String, ap::ID,       false],
      [:pkgid_pkg,         ap::ID,     ap::String,   false],
      [:pkgid_pathids,     ap::ID,     ap::ID,       true],
      [:pkgid_fmtids,      ap::ID,     ap::ID,       true],
      [:pkgid_lcsids,      ap::ID,     ap::ID,       true],
      [:pkgid_options,     ap::ID,     ap::String,   true],
      [:pkgid_src,         ap::ID,     ap::String,   false],
      [:path_pathid,       ap::String, ap::ID,       false],
      [:pathid_digest,     ap::ID,     ap::GZString, false],
      [:pathid_info,       ap::ID,     ap::String,   false],
      [:pathid_content,    ap::ID,     ap::GZString, false],
      [:pathid_bols,       ap::ID,     ap::GZString, false],
      [:pathid_hash,       ap::ID,     ap::String,   false],
      [:pathid_path,       ap::ID,     ap::String,   false],
      [:pathid_pkgid,      ap::ID,     ap::ID,       false],
      [:pathid_wordids,    ap::ID,     ap::GZString, false],
      [:type_typeid,       ap::Symbol, ap::ID,       false],
      [:typeid_type,       ap::ID,     ap::Symbol,   false],
      [:word_wordid,       ap::String, ap::ID,       false],
      [:wordid_pkgids,     ap::ID,     ap::ID,       true],
      [:wordid_word,       ap::ID,     ap::String,   false],
      [:pkgwordid_pathids, ap::String, ap::ID,       true],
      [:pathwordid_info,   ap::String, ap::String,   false],
      [:version,           ap::String, ap::String,   false],
    ]

    IDTable = [
      # id_name,    # of id     text -> id    id -> text    id -> alt
      [:type_id,    :ntypes,    :type_typeid, :typeid_type, nil],
      [:word_id,    :nwords,    :word_wordid, :wordid_word, nil],
      [:path_id,    :ncontents, :path_pathid, :pathid_path, nil],
      [:package_id, :npackages, :pkg_pkgid,   :pkgid_pkg,   nil],
      [:format_id,  :nformats,  :fabbr_fmtid, :fmtid_fabbr, :fmtid_fmt],
      [:license_id, :nlicenses, :labbr_lcsid, :lcsid_labbr, :lcsid_lcs],
    ]

    def initialize(config, read_only = false)
      raise "#{config.db_directory}: No such directory" unless 
        File.directory?(config.db_directory)
      @config = config

      validate_db_version
      @db_opened = {}
      DBTable.each {|db_name, key_type, value_type, dupsort|
        open_db(db_name, key_type, value_type, dupsort)
      }
      put_db_version unless read_only
      init_id_counters

      @opened = true
      @current_package_id = nil
      @wordid_pathids_cache = {}
    end

    private
    def init_id_counters
      @id_counters = []
      IDTable.each {|id_name, counter, db, rev_db, alt_db|
        counter = IDCounter.new(self, id_name, counter, db, rev_db, alt_db)
        name = "@" + id_name.to_s + "_counter"
        instance_variable_set(name, counter)
        self.class.class_eval { 
          attr_reader name.delete("@")
        }
        @id_counters << counter
      }
    end

    def collect_all_results(word_id)
      results = []
      if word_id
        get_package_ids(word_id).each {|package_id|
          path_ids = get_path_ids_from_package_and_word_id(package_id, word_id)
          path_ids.each {|path_id|
            results.concat(get_all_word_info(path_id, word_id))
          }
        }
      end
      return results
    end

    def db_exist?
      return false unless File.directory?(@config.db_directory)
      entries = Dir.entries_without_dots(@config.db_directory)
      # filter out file names like __db.001.
      entries = entries.find_all {|entry| not /^__/.match(entry) }
      if entries.empty?
        return false
      else
        return true
      end
    end

    def decrease_counter(key, step = 1)
      value = get_counter(key) - step
      raise DBMError.new("counter #{key} becomes minus") if value < 0
      @stat[key.to_s] = value
    end


    def do_open_db(name, key_type, value_type, dupsort)
      raise NotImplementedError.new
    end

    def each_property(id_name, get_abbrev, &block)
      properties = []
      self.send(id_name).each {|id, name|
        abbrev = self.send(get_abbrev, id)
        properties.push([id, abbrev, name])
      }
      properties.sort_by {|id, abbrev, name| name }.each {|id, abbrev, name|
        block.call(id, abbrev, name)
      }
    end

    def get_bols(path_id)
      DeltaDumper.undump_fixnums(@pathid_bols[path_id])
    end

    def open_db(db_name, key_type, value_type, dupsort)
      return if @db_opened.include?(db_name)
      db = do_open_db(db_name, key_type, value_type, dupsort)
      @db_opened[db_name] = db

      name = "@" + db_name.to_s
      instance_variable_set(name, db)
      self.class.class_eval { 
        attr_reader name.delete("@")
      }
      return db
    end

    def put_db_version
      @version["version"] = DB_VERSION
    end
      
    def validate_db_version
      return unless db_exist?
      version = "unknown"
      begin
        db = do_open_db(:version, AutoPack::String, AutoPack::String, false)
        version = db["version"]
        db.close
      rescue BDB::Fatal
      end
      if version != DB_VERSION
        m = sprintf("DB format is incomatible (version %s expected but %s)",
                    DB_VERSION, version)
        raise IncompatibleDBError.new(m)
      end
    end

    def verify_stat_integrity
      assert_equal_all(get_nformats, 
                       fmtid_fmt.length, 
                       fmtid_fabbr.length, 
                       fabbr_fmtid.length)
      assert_equal_all(get_npackages,
                       pkgid_pkg.length, 
                       pkg_pkgid.length)
      assert_equal_all(get_ncontents,
                       path_pathid.length, 
                       pathid_path.length,
                       pathid_content.length,
                       pathid_info.length)
      assert_equal_all(get_nwords,  
                       word_wordid.length)
      nlines_indexed = 0
      @pathid_info.each_key {|path_id|
        info = get_content_info(path_id)
        nlines_indexed += info.nlines if info.indexed?
      }
      assert_equal(get_nlines_indexed, nlines_indexed)
    end

    def verify_seq_integrity
      IDTable.each {|id_name, counter, db, rev_db, alt_db|
        id = (self.send(rev_db).get_last_key or 0)
        assert(id <= (@seq["last_" + id_name.to_s] or 0))
      }
    end

    public
    def binary_content?(path_id)
      format_id = get_format_id_from_path_id(path_id)
      get_format_abbrev(format_id) == "binary"
    end

    def close
      flush_cache
      raise DBMError.new("dbm is already closed") unless @opened
      @db_opened.each {|name, db| 
        db.close
      }
      @opened = false
    end

    def consistent?
      verify_stat_integrity
      verify_seq_integrity
      return true
    end

    def decrease_counter(key, step = 1)
      value = get_counter(key) - step
      raise DBMError.new("counter #{key} becomes minus") if value < 0
      @stat[key.to_s] = value
    end

    def each_db_name
      @db_opened.each_key {|db_name| yield(db_name.to_s) }
    end

    def each_format(&block)
      each_property(:fmtid_fmt, :get_format_abbrev, &block)
    end

    def each_license(&block)
      each_property(:lcsid_lcs, :get_license_abbrev, &block)
    end

    def each_package_name
      @pkgid_pkg.each_value {|value| yield(value) }
    end

    def each_word(&block)
      @word_wordid.each_key {|word| yield(word) }
    end

    def find_all(pattern)
      word_id = @word_wordid[pattern]
      results = collect_all_results(word_id)
      return results
    end

    def find_all_by_prefix(pattern)
      raise NotImplementedError.new("should be implemented in a sub class")
    end

    def find_all_by_regexp(pattern)
      regexp = Regexp.new(pattern)
      results = []
      @word_wordid.each {|word, word_id|
        if regexp.match(word)
          results.concat(collect_all_results(word_id))
        end
      }
      return results
    end

    def find_word_info(path_id, word_id)
      get_all_word_info(path_id, word_id).each {|info|
        yield(info)
      }
    end

    def flush_cache
      wordids = @wordid_pathids_cache.keys.sort!
      wordids.each {|word_id|
        package_word_id = AutoPack.pack_id2(@current_package_id, word_id)
        @wordid_pathids_cache[word_id].each {|path_id|
          @pkgwordid_pathids[package_word_id] = path_id
        }
      }
      wordids.each {|word_id|
        @wordid_pkgids[word_id] = @current_package_id
      }
      @wordid_pathids_cache.clear
      @id_counters.each {|counter| counter.flush}
    end

    def get_all_word_info(path_id, word_id)
      path_word_id = AutoPack.pack_id2(path_id, word_id)
      dump = @pathwordid_info[path_word_id]
      return [] if dump.nil?
      bols = get_bols(path_id)
      bol = bols.shift
      assert_equal(0, bol)

      lineno = 0
      DeltaDumper.undump_tuples(WordInfo, dump).map {|seqno, byteno, type_id|
        while bol and bol <= byteno
          lineno += 1
          bol = bols.shift
        end
        type = get_type(type_id)
        WordInfo.new(word_id, path_id, seqno, byteno, type_id, type, lineno)
      }
    end

    def get_content_hash(path_id)
      @pathid_hash[path_id]
    end

    def get_counter(key)
      @stat[key.to_s] or 0
    end

    def get_content(path_id)
      @pathid_content[path_id]
    end

    def get_content_info(path_id)
      dump = @pathid_info[path_id]
      assert_non_nil(dump)
      return ContentInfo.load(dump)
    end

    def get_digest(path_id)
      dump = @pathid_digest[path_id]
      return [] if dump.nil?
      DeltaDumper.undump_tuples(DigestInfo, dump).map {|data|
        data.push(get_type(data.last))
        DigestInfo.new(*data)
      }
    end

    def get_format_abbrev(format_id)
      @fmtid_fabbr[format_id]
    end

    def get_format_id(format_abbrev)
      @fabbr_fmtid[format_abbrev]
    end

    def get_format_id_from_path_id(path_id)
      get_content_info(path_id).format_id
    end

    def get_format_ids_from_package_id(package_id)
      @pkgid_fmtids.duplicates(package_id)
    end

    def get_format_name(format_id)
      @fmtid_fmt[format_id]
    end

    def get_license_abbrev(license_id)
      @lcsid_labbr[license_id]
    end

    def get_license_id(license_abbrev)
      @labbr_lcsid[license_abbrev]
    end

    def get_license_id_from_path_id(path_id)
      get_content_info(path_id).license_id
    end

    def get_license_ids_from_package_id(package_id)
      @pkgid_lcsids.duplicates(package_id)
    end

    def get_license_name(license_id)
      @lcsid_lcs[license_id]
    end

    def get_ncontents
      get_counter(:ncontents)
    end

    def get_ncontents_by_format_id(format_id)
      format_abbrev = get_format_abbrev(format_id)
      key = make_ncontents_by_format_key(format_abbrev)
      return get_counter(key)
    end

    def get_ncontents_by_license_id(license_id)
      license_abbrev = get_license_abbrev(license_id)
      key = make_ncontents_by_license_key(license_abbrev)
      return get_counter(key)
    end

    def get_ncontents_indexed
      get_counter(:ncontents_indexed)
    end

    def get_ncontents_in_package(package_name)
      package_id = get_package_id(package_name)
      @pkgid_pathids.duplicates(package_id).length
    end

    def get_nformats
      get_counter(:nformats)
    end

    def get_nlines_indexed
      get_counter(:nlines_indexed)
    end

    def get_npackages
      get_counter(:npackages)
    end

    def get_nwords
      get_counter(:nwords)
    end

    def get_package_id(package_name)
      @pkg_pkgid[package_name]
    end

    def get_package_id_from_path_id(path_id)
      @pathid_pkgid[path_id]
    end

    def get_package_ids(word_id)
      @wordid_pkgids.duplicates(word_id)
    end

    def get_package_name(package_id)
      @pkgid_pkg[package_id]
    end

    def get_package_names
      @pkgid_pkg.values
    end

    def get_package_options(package_id)
      options = {}
      values = @pkgid_options.duplicates(package_id)
      values.each {|value|
        k, v = value.split(":", 2)
        k = k.intern
        case k
        when :exclude_pattern
          v = Regexp.new(v)
        when :noindex_formats
          v = v.split(",")
        else
          raise DBMError.new("#{k}: unknown option")
        end
        options[k] = v
      }
      assert(options[:exclude_pattern])
      assert(options[:noindex_formats])
      return options
    end

    def get_path(path_id)
      @pathid_path[path_id]
    end

    def get_path_id(path)
      @path_pathid[path]
    end

    def get_path_ids(package_id)
      @pkgid_pathids.duplicates(package_id)
    end

    def get_path_ids_from_package_and_word_id(package_id, word_id)
      package_word_id = AutoPack.pack_id2(package_id, word_id)
      return @pkgwordid_pathids.duplicates(package_word_id)
    end

    def get_source_uri(package_id)
      @pkgid_src[package_id]
    end

    def get_type(type_id)
      @typeid_type[type_id]
    end

    def get_type_id(type)
      @type_id_counter.get_id(type)
    end

    def get_word(word_id)
      @wordid_word[word_id]
    end

    def get_word_id(word)
      @word_wordid[word]
    end

    def get_word_ids(path_id)
      DeltaDumper.undump_ids(@pathid_wordids[path_id])
    end

    def has_format_id?(format_id)
      @fmtid_fmt.has_key?(format_id)
    end

    def has_format_abbrev?(format_abbrev)
      @fabbr_fmtid.has_key?(format_abbrev)
    end

    def has_license_id?(license_id)
      @lcsid_lcs.has_key?(license_id)
    end

    def has_license_abbrev?(license_abbrev)
      @labbr_lcsid.has_key?(license_abbrev)
    end

    def has_package?(package_name)
      @pkg_pkgid.include?(package_name)
    end

    def has_path?(path)
      @path_pathid.include?(path)
    end

    def has_type?(type)
      @type_typeid.include?(type)
    end

    def has_word?(word)
      wordid = @word_wordid[word]
      if wordid
        return true
      else
        return false
      end
    end

    def increase_counter(key, step = 1)
      @stat[key.to_s] = get_counter(key) + step
    end

    def make_ncontents_by_format_key(format_abbrev)
      ("ncontents_format_" + format_abbrev).intern
    end

    def make_ncontents_by_license_key(license_abbrev)
      ("ncontents_license_" + license_abbrev).downcase.intern
    end

    # FIXME: Ad hoc serialization. We avoid using Marshal
    # not to make the DB Ruby-dependent.
    def put_package_options(package_id)
      @pkgid_options[package_id] = sprintf("exclude_pattern:%s", 
                                           @config.exclude_pattern.to_s)
      @pkgid_options[package_id] = sprintf("noindex_formats:%s",
                                           @config.noindex_formats.join(","))
    end

    def put_pathid_wordids(package_id, path_id, word_ids)
      @current_package_id = package_id
      word_ids.each {|word_id|
        pathids = (@wordid_pathids_cache[word_id] ||= [])
        pathids << path_id
      }
    end
  end
end

