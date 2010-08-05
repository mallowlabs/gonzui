#
# deindexer.rb - deindexer implementation
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

require 'ftools'
require 'langscan'

module Gonzui
  class Deindexer
    include Util

    def initialize(config, dbm, normalized_path)
      @config = config
      @dbm = dbm
      @normalized_path = normalized_path
      @path_id = @dbm.get_path_id(@normalized_path)
      @package_id = @dbm.get_package_id_from_path_id(@path_id)
      @package_name = @dbm.get_package_name(@package_id)
    end

    private
    def deindex_content
      word_ids = @dbm.get_word_ids(@path_id)
      word_ids.each {|word_id|
        package_word_id = AutoPack.pack_id2(@package_id, word_id)
        @dbm.pkgwordid_pathids.delete_both(package_word_id, @path_id)
        unless @dbm.pkgwordid_pathids.has_key?(package_word_id)
          @dbm.wordid_pkgids.delete_both(word_id, @package_id)
        end

        unless @dbm.wordid_pkgids.has_key?(word_id)
          word = @dbm.wordid_word[word_id]
          assert_non_nil(word)
          @dbm.wordid_word.delete(word_id) 
          @dbm.word_wordid.delete(word)
          @dbm.decrease_counter(:nwords)
        end
        path_word_id = AutoPack.pack_id2(@path_id, word_id)
        @dbm.pathwordid_info.delete(path_word_id)
      }
      @dbm.pathid_wordids.delete(@path_id)
      @dbm.pathid_bols.delete(@path_id)
    end

    def remove_digest
      format_id = @dbm.get_format_id_from_path_id(@path_id)
      digest = @dbm.get_digest(@path_id)

      format_abbrev = @dbm.get_format_abbrev(format_id)
      content = @dbm.get_content(@path_id)
      @dbm.pathid_digest.delete(@path_id)
    end

    def remove_property(get_id, get_abbrev, get_name, make_key, get_ncontents,
                        counter_name, abbr_id, id_abbr, id_name)
      id = @dbm.send(get_id, @path_id)
      abbrev = @dbm.send(get_abbrev, id)
      @dbm.decrease_counter(@dbm.send(make_key, abbrev))
      ncontents = @dbm.send(get_ncontents, id)
      if ncontents == 0
        name = @dbm.send(get_name, id)
        @dbm.send(id_name).delete(id)
        @dbm.send(id_abbr).delete(id)
        @dbm.send(abbr_id).delete(abbrev)
        @dbm.decrease_counter(counter_name)
      end
    end

    def remove_format
      remove_property(:get_format_id_from_path_id,
                      :get_format_abbrev,
                      :get_format_name,
                      :make_ncontents_by_format_key,
                      :get_ncontents_by_format_id,
                      :nformats,
                      :fabbr_fmtid,
                      :fmtid_fabbr,
                      :fmtid_fmt)
    end

    def remove_license
      remove_property(:get_license_id_from_path_id,
                      :get_license_abbrev,
                      :get_license_name,
                      :make_ncontents_by_license_key,
                      :get_ncontents_by_license_id,
                      :nlicenses,
                      :labbr_lcsid,
                      :lcsid_labbr,
                      :lcsid_lcs)
    end

    def remove_package_if_necessary
      return unless package_empty?
      @dbm.pkg_pkgid.delete(@package_name)
      @dbm.pkgid_pkg.delete(@package_id)
      @dbm.pkgid_fmtids.delete(@package_id)
      @dbm.pkgid_lcsids.delete(@package_id)
      @dbm.pkgid_src.delete(@package_id)
      @dbm.pkgid_options.delete(@package_id)
      @dbm.decrease_counter(:npackages)
    end

    def remove_path
      path = @dbm.get_path(@path_id)
      @dbm.path_pathid.delete(@normalized_path)
      @dbm.pathid_path.delete(@path_id)
      @dbm.pkgid_pathids.delete_both(@package_id, @path_id)
    end

    def remove_content_common
      remove_format
      remove_license
      @dbm.pathid_content.delete(@path_id)
      @dbm.pathid_pkgid.delete(@path_id)
      @dbm.pathid_info.delete(@path_id)
      @dbm.pathid_hash.delete(@path_id)
      @dbm.decrease_counter(:ncontents)
      vprintf("removed: %s", @normalized_path)
    end

    def remove_binary_content
      remove_content_common
    end

    def remove_indexed_content
      deindex_content
      remove_digest
      nlines = @dbm.get_content_info(@path_id).nlines
      @dbm.decrease_counter(:ncontents_indexed)
      @dbm.decrease_counter(:nlines_indexed, nlines)

      remove_content_common
    end

    def remove_content
      if @dbm.binary_content?(@path_id)
        remove_binary_content
      else
        remove_indexed_content
      end
    end

    def package_empty?
      @dbm.get_path_ids(@package_id).empty?
    end

    public 
    def deindex
      remove_path
      remove_content
      remove_package_if_necessary
    end
  end
end
