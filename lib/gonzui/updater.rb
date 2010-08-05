#
# updater.rb - update contents in gonzui.db
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

require 'digest/md5'
require "gonzui/progressbar"

module Gonzui
  class AbstractUpdater
    include Util

    def initialize(config, options = {})
      @start_time = Time.now
      @dbm = DBM.open(config)
      @config = config
      @ncontents = 0
      @npackages = 0
      @show_progress = options[:show_progress]
    end

    private
    def make_progress_bar(title, total)
      klass = if @config.verbose
                NullObject
              elsif @show_progress
                ProgressBar
              else
                NullObject
              end
      return klass.new(title, total)
    end

    def do_task_name
      NotImplementedError.new
    end

    def task_name
      do_task_name
    end

    def deindex_content_internal(normalized_path)
      deindexer = Deindexer.new(@config, @dbm, normalized_path)
      deindexer.deindex
    end

    def deindex_content(normalized_path)
      protect_from_signals {
        deindex_content_internal(normalized_path)
        @ncontents += 1
      }
    end

    def index_content_internal(source_uri, normalized_path, content, 
                               options = {})
      indexer = Indexer.new(@config, @dbm, source_uri, normalized_path, 
                            content, options)
      indexer.index
    end

    def index_content(source_uri, normalized_path, content, options = {})
      protect_from_signals {
        index_content_internal(source_uri, normalized_path, content, options)
        @ncontents += 1
      }
    end

    def update_content(source_uri, normalized_path, content, options = {})
      protect_from_signals {
        deindex_content_internal(normalized_path)
        index_content_internal(source_uri, normalized_path, content, options)
        @ncontents += 1
      }
    end

    public
    def summary
      elapsed = Time.now - @start_time
      format = "%d contents of %d packages %s in %.2f sec. (%.2f contents / sec.)\n"
      summary = sprintf(format, @ncontents, @npackages, task_name, elapsed,
                        @ncontents / elapsed)
      return summary
    end

    def finish
      @dbm.close
    end
  end

  class UpdateDiff
    def initialize(config, dbm, fetcher, package_id, package_name, 
                   options = {})
      @config = config
      @dbm = dbm
      @fetcher = fetcher
      @package_id = package_id
      @package_name = package_name
      @exclude_pattern = options[:exclude_pattern] 

      @paths_to_be_removed = []
      @paths_to_be_added = []
      @paths_to_be_updated = []

      @paths_in_db = {}
      @dbm.get_path_ids(package_id).each {|path_id|
        normalized_path = @dbm.get_path(path_id)
        @paths_in_db[normalized_path] = :unseen
      }
      collect
    end

    private
    def file_updated?(relative_path, normalized_path)
      path_id = @dbm.get_path_id(normalized_path)
      content = nil
      begin
        content = @fetcher.fetch(relative_path)
      rescue => e
        return false # deleted after collecting a list
      end
      content_hash = Digest::MD5.hexdigest(content.text)
      return content_hash != @dbm.get_content_hash(path_id)
    end

    def push_added_path(relative_path, normalized_path)
      @paths_to_be_added.push([relative_path, normalized_path])
    end

    def push_updated_path(relative_path, normalized_path)
      @paths_to_be_updated.push([relative_path, normalized_path])
    end

    def push_removed_path(normalized_path)
      @paths_to_be_removed.push(normalized_path)
    end

    def collect
      relative_paths = @fetcher.collect
      relative_paths.each {|relative_path|
        normalized_path = File.join(@package_name, relative_path)
        @paths_in_db[normalized_path] = :seen
        if @dbm.has_path?(normalized_path)
          if file_updated?(relative_path, normalized_path)
            push_updated_path(relative_path, normalized_path)
          end
        else
          push_added_path(relative_path, normalized_path)
        end
      }
      @paths_in_db.each {|normalized_path, mark|
        push_removed_path(normalized_path) if mark == :unseen
      }
    end

    public
    def each_added_path
      @paths_to_be_added.each {|relative_path, normalized_path|
        yield(relative_path, normalized_path)
      }
    end

    def each_updated_path
      @paths_to_be_updated.each {|relative_path, normalized_path|
        yield(relative_path, normalized_path)
      }
    end

    def each_removed_path
      @paths_to_be_removed.each {|normalized_path|
        yield(normalized_path)
      }
    end

    def ncontents
      @paths_to_be_added.length + @paths_to_be_updated.length +
        @paths_to_be_removed.length
    end
  end

  class SourceDisappeared < GonzuiError; end

  class Updater < AbstractUpdater
    private
    def do_task_name
      "updated"
    end

    def make_fetcher(config, source_uri, options)
      return Fetcher.new(config, source_uri, options)
    rescue FetchFailed
      raise SourceDisappeared.new
    end

    def update_package_internal(diff, fetcher, package_name, 
                                source_uri, options)
      pbar = make_progress_bar(package_name, diff.ncontents)
      diff.each_removed_path {|normalized_path|
        deindex_content(normalized_path)
        pbar.inc
      }
      diff.each_added_path {|relative_path, normalized_path|
        content = fetcher.fetch(relative_path)
        index_content(source_uri, normalized_path, content, options)
        pbar.inc
      }
      diff.each_updated_path {|relative_path, normalized_path|
        content = fetcher.fetch(relative_path)
        update_content(source_uri, normalized_path, content, options)
        pbar.inc
      }
      pbar.finish
    end

    def update_package(package_name)
      package_id = @dbm.get_package_id(package_name)
      source_uri = URI.parse(@dbm.get_source_uri(package_id))
      options = @dbm.get_package_options(package_id)
      fetcher = make_fetcher(@config, source_uri, options)
      diff = UpdateDiff.new(@config, @dbm, fetcher, package_id, 
                            package_name, options)
      if diff.ncontents > 0
        update_package_internal(diff, fetcher, package_name, 
                                source_uri, options)
        @npackages += 1
        return true
      else
        return false
      end
    end

    public
    def update
      # Don't use #each_package_name to avoid
      # deadlock. #each_package_name creates and holds a
      # cursor while an iteration
      @dbm.get_package_names.each {|package_name|
        begin
          updated_p = update_package(package_name)
          yield(package_name) if block_given? and updated_p
        rescue SourceDisappeared
          wprintf("%s: source disappeared", package_name)
        ensure
          @dbm.flush_cache
        end
      }
    end
  end
end
