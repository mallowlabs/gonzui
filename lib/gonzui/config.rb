#
# config.rb - a config library
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  class Config
    include Util

    def initialize
      #
      # All paths should be expanded to absolute paths
      # because the current directory would be changed when
      # a process becomes a daemon.
      #
      @temporary_directory = ENV['tmp'] || "/tmp"
      @db_directory = File.expand_path("gonzui.db")
      @cache_directory = File.join(@db_directory, "cache")
      @gonzui_log_file = File.expand_path("gonzui.log")

      @db_cache_size = 5 * 1024 ** 2

      @quiet = false
      @verbose = false

      @utf8 = true
      @encoding_preference = UTF8::Preference

      @noindex_formats = []
      # FIXME: should be more flexible
      @exclude_pattern = /~$|\.bak$|CVS|\.svn|\.git/

      #
      # For gonzui-server
      #
      @pid_file = File.expand_path("gonzui.pid")
      @daemon = false
      @access_log_file = File.expand_path("access.log")
      @catalog_directory = choose_directory("catalog")
      @doc_directory = choose_directory("doc")
      @http_port = Gonzui::HTTP_PORT
      @bind_address = '*'
      @user = nil
      @group = nil
      @site_title = "gonzui"
      @base_mount_point = "/"

      @default_results_per_page = 10
      @max_results_per_page = 50
      @max_pages = 20
      @max_words = 10
      @max_packages_per_page = 100
      @nresults_candidates = [10, 20, 30, 50]

      set_user_and_group if unix?
      instance_variables.each {|name|
	self.class.class_eval { 
          attr_accessor name.delete("@")
        }
      }
    end

    private
    def choose_directory(base_name)
      directory = nil
      [base_name, 
       File.join(File.dirname($0), "..", Gonzui::PKGDATADIR, base_name), 
       File.join(Gonzui::PKGDATADIR, base_name)].each do |d|
          directory = d
          break if File.directory?(directory)
      end
      return File.expand_path(directory)
    end

    def set_user_and_group
      require 'etc'
      u = Etc::getpwuid(Process.uid)
      g = Etc::getgrgid(Process.gid)
      @user  = u.name
      @group = g.name
    end

    def keys
      instance_variables.map {|name| name.delete("@").intern }
    end

    public
    def max_results_overall
      @max_results_per_page * @max_pages
    end

    def dump(out = STDOUT)
      len = keys.map {|key| key.inspect.length }.max
      out.puts "{"
      keys.sort_by {|key| key.to_s }.each {|key|
        out.printf("  %-#{len}s => %s,\n", key.inspect, send(key).inspect)
      }
      out.puts "}"
    end

    def load(file_name)
      f = File.open(file_name)
      hash = eval(f.read)
      f.close
      return if hash.nil?
      hash.each {|key, value|
        send(key.to_s + "=", value)
      }
    end
  end
end
