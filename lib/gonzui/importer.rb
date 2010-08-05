#
# importer.rb - import contents to gonzui.db
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

require 'uri'

module Gonzui
  class ImporterError < GonzuiError; end

  class Importer < AbstractUpdater
    def initialize(config, options = {})
      super(config, options)
      # to be initialized
      @last_package_name = nil
    end
    attr_reader :last_package_name

    private
    def import_package(fetcher, source_uri)
      package_name = fetcher.package_name
      raise ImporterError.new("#{package_name}: already exists") if 
        @dbm.has_package?(package_name)

      relative_paths = fetcher.collect
      pbar = make_progress_bar(package_name, relative_paths.length)
      begin
        relative_paths.each {|relative_path|
          begin
            normalized_path = File.join(package_name, relative_path)
            content = nil
            begin
              content = fetcher.fetch(relative_path)
            rescue => e
              vprintf("fetch failed: %s: %s\n%s", relative_path, e.message)
              next
            end
            index_content(source_uri, normalized_path, content)
          ensure
            pbar.inc
          end
        }
      ensure
        @dbm.flush_cache
      end
      pbar.finish
      @npackages += 1
      @last_package_name = package_name
    end

    def do_task_name
      "imported"
    end

    public
    def import(source_uri)
      fetcher = Fetcher.new(@config, source_uri)
      begin
        import_package(fetcher, source_uri)
      ensure
        fetcher.finish
      end
    end

    def summary
      summary = super
      if @config.verbose
        stat = Indexer.statistics
        summary += "\n" + stat unless stat.empty?
      end
      return summary
    end

    def finish
      @dbm.close
    end
  end
end
