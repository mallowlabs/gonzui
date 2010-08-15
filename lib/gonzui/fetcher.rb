#
# fetcher.rb - fetch contents from various sources
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

require 'open-uri'
require 'webrick/httputils'
require 'ftools'

module Gonzui
  class FetcherError < GonzuiError; end
  class FetchFailed < FetcherError; end

  module Fetcher
    extend Util
    FetcherRegistory = {}

    module_function
    def new(config, source_uri, options = {})
      klass = FetcherRegistory[source_uri.scheme]
      if klass.nil?
        raise FetcherError.new("#{source_uri.scheme}: unsupported scheme")
      end
      if source_uri.path.nil?
        raise FetcherError.new("#{source_uri.to_s}: malformed URI")
      end
      fetcher = klass.new(config, source_uri, options)
      if fetcher.need_extraction? # fallback to FileFetcher
        extractor = fetcher.get_extractor
        directory = extractor.extract
        fetcher.finish

        source_uri = URI.from_path(directory)
        fetcher = FileFetcher.new(config, source_uri, options)
        fetcher.add_finishing_proc(lambda { extractor.clean })
      end
      return fetcher
    end

    def register(klass)
      FetcherRegistory[klass.scheme] = klass
    end
  end

  class AbstractFetcher
    include Util

    def initialize(config, source_uri, options = {})
      @config = config
      @source_uri = source_uri
      @exclude_pattern = (options[:exclude_pattern] or @config.exclude_pattern)
      @finishing_procs = []
      @base_uri = source_uri
    end

    public
    def add_finishing_proc (proc)
      @finishing_procs.push(proc)
    end

    def collect
      raise NotImplementedError.new
    end

    def exclude?(relative_path)
      @exclude_pattern.match(relative_path)
    end

    def fetch(relative_path)
      raise NotImplementedError.new
    end

    def finish
      @finishing_procs.each {|proc| proc.call }
    end

    def get_extractor
      raise NotImplementedError.new
    end

    def need_extraction?
      raise NotImplementedError.new
    end

    def package_name
      File.basename(@base_uri.path)
    end
  end

  class FileFetcher < AbstractFetcher
    def self.scheme
      "file"
    end

    def initialize(config, source_uri, options)
      super(config, source_uri, options)
      begin
        File.ftype(source_uri.path)
      rescue => e
        raise FetchFailed.new(e.message)
      end
    end

    private
    def restore_path(relative_path)
      File.join(@base_uri.path, relative_path)
    end

    public
    def need_extraction?
      not File.directory?(@source_uri.path)
    end

    def get_extractor
      return Extractor.new(@config, @source_uri.path)
    end

    def fetch(relative_path)
      path = restore_path(relative_path)
      content = File.read(path)
      mtime = File.mtime(path)
      return Content.new(content, mtime, path)
    end

    def collect
      directory = @base_uri.path
      relative_paths = []
      Dir.all_files(directory).map {|file_name|
        next if exclude?(file_name)
        relative_path = File.relative_path(file_name, directory)
        relative_paths.push(relative_path)
      }
      return relative_paths
    end

    Fetcher.register(self)
  end

  # FIXME: very ad hoc implementation
  class HTTPFetcher < AbstractFetcher
    include TemporaryDirectoryUtil
    def self.scheme
      "http"
    end

    def initialize(config, source_uri, options)
      super(config, source_uri, options)
      begin
        open(source_uri.to_s) {|f| 
          @content = f.read
          @content_type = f.content_type
          @base_uri = f.base_uri
        }
      rescue OpenURI::HTTPError => e
        raise FetchFailed.new("#{source_uri.to_s}: #{e.message}")
      end

      # http://example.com/foo/index.html => http://example.com/foo/
      unless /\/$/.match(@base_uri.path) #/
        @base_uri.path = File.dirname(@base_uri.path) + "/"
      end
      set_temporary_directory(@config.temporary_directory)
    end

    def restore_uri(relative_path)
      u = @base_uri.to_s + relative_path
      URI.parse(u)
    end

    public
    def need_extraction?
      @content_type != "text/html"
    end

    def get_extractor
      prepare_temporary_directory
      tmp_name = File.join(self.temporary_directory, 
                           File.basename(@source_uri.path))
      File.open(tmp_name, "w") {|f| f.write(@content) }
      add_finishing_proc(lambda { clean_temporary_directory })
      return Extractor.new(@config, tmp_name)
    end

    def fetch(relative_path)
      uri = restore_uri(relative_path)
      content = mtime = nil
      open(uri.to_s) {|f| 
        content = f.read 
        mtime = f.last_modified
      }
      return Content.new(content, mtime)
    end

    def collect
      relative_paths = []
      @content.scan(/href=(["'])(.*?)\1/i).each {|qmark, link|
        u = URI.parse(link)
        next if u.path.nil?
        u.path.chomp!("/")
        next unless u.relative?
        next if /^\./.match(u.path)
        next if exclude?(u.path)
        relative_paths.push(u.path)
      }
      return relative_paths
    end
      
    Fetcher.register(self)
  end

  class AptFetcher < AbstractFetcher
    def self.scheme
      "apt-get"
    end

    def need_extraction?
      true
    end

    def get_extractor
      package_name = @source_uri.path.prechop
      return AptGet.new(@config, package_name)
    end

    Fetcher.register(self)
  end

  class CVSFetcher < AbstractFetcher
    def self.scheme
      "cvs"
    end

    def need_extraction?
      true
    end

    def get_extractor
      query = WEBrick::HTTPUtils.parse_query(@source_uri.query)
      prefix = query["prefix"]
      mozule = query["module"]
      assert_non_nil(mozule)
      root = @source_uri.path
      root = @source_uri.host + ":" + root if @source_uri.host
      root = prefix + "@" + root if prefix
      return CVS.new(@config, root, mozule)
    end

    Fetcher.register(self)
  end

  class SubversionFetcher < AbstractFetcher
    def self.scheme
      "svn"
    end

    def need_extraction?
      true
    end

    def get_extractor
      query = WEBrick::HTTPUtils.parse_query(@source_uri.query)
      mozule = query["module"]
      assert_non_nil(mozule)
      uri = @source_uri.dup
      uri.scheme = query["original_scheme"] if query["original_scheme"]
      uri.query = nil
      root = uri.to_s
      # FIXME: kludge for replacing file:/home/... ->
      # file:///home/... because subversion doesn't allow
      # the former URI.
      root.gsub!(%r!^file:/+!, "file:///") if uri.scheme == "file" 
      return Subversion.new(@config, root, mozule)
    end

    Fetcher.register(self)
  end

  class GitFetcher < AbstractFetcher
    def self.scheme
      "git"
    end

    def need_extraction?
      true
    end

    def get_extractor
      query = WEBrick::HTTPUtils.parse_query(@source_uri.query)
      mozule = query["module"]
      uri = @source_uri.dup
      uri.scheme = query["original_scheme"] if query["original_scheme"]
      uri.query = nil
      root = uri.to_s
      # FIXME: kludge for replacing file:/home/... ->
      # file:///home/... because git doesn't allow
      # the former URI.
      root.gsub!(%r!^file:/+!, "file:///") if uri.scheme == "file"
      return Git.new(@config, root, mozule)
    end

    Fetcher.register(self)
  end
end
