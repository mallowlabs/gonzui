#
# bdbdbm.rb - bdb implementation of gonzui DB
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

require 'bdb'

module Gonzui
  class BDBDBM < AbstractDBM
    def initialize(config, read_only = false)
      retried = false
      begin
        @db_mode  = if read_only then BDB::RDONLY else BDB::CREATE end
        env_flags = BDB::CREATE | BDB::INIT_MPOOL | BDB::INIT_LOCK
        options = {}
        options["set_cachesize"] = config.db_cache_size
        @db_env = BDB::Env.new(config.db_directory, env_flags, options)
        super(config, read_only)
      rescue BDB::Fatal => e
        raise e if retried
        retried = true
        #
        # "Lock table is out of available locker entries"
        # error ocasionally occurs if a process using
        # Gonzui::BDMDBM is killed by SIGKILL forcibly. In
        # that case, we can remove Berkeley DB Environment
        # to solve the error.
        #
        BDB::Env.remove(config.db_directory, BDB::FORCE)
        retry
      end
    end

    private
    def do_open_db(name, key_type, value_type, dupsort)
      options = {}
      options["env"] = @db_env
      if key_type == AutoPack::ID && !dupsort
        options["set_array_base"] = 0
        options["set_store_value"] = value_type.store if value_type.store
        options["set_fetch_value"] = value_type.fetch if value_type.fetch
        db = BDB::Recno.open(name.to_s, nil, @db_mode, 0644, options)
      else
        options["set_flags"] = BDB::DUPSORT if dupsort
        options["set_store_key"] = key_type.store if key_type.store
        options["set_fetch_key"] = key_type.fetch if key_type.fetch
        options["set_store_value"] = value_type.store if value_type.store
        options["set_fetch_value"] = value_type.fetch if value_type.fetch
        db = BDB::Btree.open(name.to_s, nil, @db_mode, 0644, options)
      end
      db.extend(BDBExtension)
      return db
    end

    public
    def close
      super
      @db_env.close
    end

    def find_all_by_prefix(pattern)
      results = []
      self.word_wordid.each_by_prefix(pattern) {|word, word_id|
        results.concat(collect_all_results(word_id))
      }
      return results
    end
  end

  module BDBExtension
	def duplicates(key , assoc = false)
		super(key, assoc) rescue super(key, 0) # hack for Windows
	end

    def each_by_prefix(prefix)
      values = []
      cursor = self.cursor
      begin
        if pair = cursor.set_range(prefix)
          begin
            k, v = pair
            break unless k[0, prefix.length] == prefix
            yield(k, v)
          end while pair = cursor.next
        end
        return values
      ensure
        cursor.close
      end
    end

    def delete_both(key, value)
      cursor = self.cursor
      begin
        pair = cursor.get(BDB::GET_BOTH, key, value)
        cursor.delete unless pair.nil?
      ensure
        cursor.close
      end
    end

    def get_last_key
      cursor = self.cursor
      begin
        k, v = cursor.last
        return k
      ensure
        cursor.close
      end
    end
  end
end
