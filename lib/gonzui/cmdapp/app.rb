#
# app.rb - command line application framework
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

require 'getoptlong'

# gonzui applications use UTF-8 for the internal encoding.
$KCODE = "u"

module Gonzui
  class CommandLineApplication
    include Util
    extend Util

    def initialize
      @config = Config.new

      # ~/.gonzuirc has precedence over /etc/gonzuirc
      file_names = []
      file_names.push(File.join(ENV['HOME'], ".gonzuirc")) if ENV['HOME']
      file_names.push(File.join(SYSCONFDIR, "gonzuirc"))
      file_names.each {|file_name|
        if File.exist?(file_name)
          @config.load(file_name)
          break
        end
      }
    end

    def parse_options_to_hash(option_table)
      begin
        options = {}
        parser = GetoptLong.new
        parser.set_options(*option_table)
        parser.quiet = true
        parser.each_option {|name, arg|
          options[name.sub(/^--/, "")] = arg
        }
        return options
      rescue => e
        eprintf("%s", e.message)
      end
    end

    def show_version
      printf("%s %s\n", program_name, Gonzui::VERSION)
      exit
    end

    def dump_config
      @config.dump
      exit
    end

    def be_quiet
      devnull = if windows? then "NUL" else "/dev/null" end
      STDOUT.reopen(devnull)
    end

    def ensure_db_directory_available
      eprintf "#{@config.db_directory}: DB directory not found" unless
        File.directory?(@config.db_directory)
    end

    def show_usage
      do_show_usage
      cache_size = @config.db_cache_size / 1024 ** 2
      puts "      --gonzuirc=FILE            specify alternate run control file"
      puts "      --dump-config              dump configuration"
      puts "  -d, --db-dir=DIR               use DB directory DIR"
      puts "      --db-cache=NUM             use NUM megabytes of DB cache [#{cache_size}]"
      puts "      --list-formats             list all supported formats"
      puts "      --help                     show this help message"
      puts "  -q, --quiet                    suppress all normal output"
      puts "  -v, --verbose                  output progress and statistics"
      puts "      --version                  print version information and exit"
      exit
    end

    def show_formats
      max = LangScan::modules.sort_by {|m| m.name.length }.last.name.length
      LangScan::modules.sort_by {|m| m.name }.each {|m|
        printf("%-#{max}s %s\n", m.name, m.abbrev)
      }
      exit
    end

    def process_common_options(options)
      show_version if options["version"]
      show_usage if options["help"]
      show_formats if options["list-formats"]
      @config.quiet = true if options["quiet"]
      @config.verbose = true if options["verbose"]
      @config.load(File.expand_path(options["gonzuirc"])) if 
        options["gonzuirc"]
      @config.db_directory = File.expand_path(options["db-dir"]) if
        options["db-dir"]
      @config.db_cache_size = (options["db-cache"].to_f * 1024 ** 2).to_i if
        options["db-cache"]

      UTF8.set_preference(@config.encoding_preference)
      set_verbosity(@config.verbose)
      be_quiet if @config.quiet
      dump_config if options["dump-config"]
    end

    def parse_options
      option_table = [
        ["--help",                GetoptLong::NO_ARGUMENT],
        ["--version",             GetoptLong::NO_ARGUMENT],
        ["--quiet",         "-q", GetoptLong::NO_ARGUMENT],
        ["--verbose",       "-v", GetoptLong::NO_ARGUMENT],
        ["--db-dir",        "-d", GetoptLong::REQUIRED_ARGUMENT],
        ["--db-cache",            GetoptLong::REQUIRED_ARGUMENT],
        ["--list-formats",        GetoptLong::NO_ARGUMENT],
        ["--dump-config",         GetoptLong::NO_ARGUMENT],
        ["--gonzuirc",            GetoptLong::REQUIRED_ARGUMENT]
      ]
      option_table.concat(do_get_option_table)
      options = parse_options_to_hash(option_table)
      process_common_options(options)
      do_process_options(options)
    end      

    def init_logger
      @logger = Logger.new(@config.gonzui_log_file)
    end

    def init_logger_with_stderr
      @logger = Logger.new(@config.gonzui_log_file)
      @logger.attach(STDERR)
    end

    def start
      begin
        do_start
      rescue Interrupt, Errno::EPIPE
      end
    end


    # Hook methods
    def do_show_usage
      raise NotImplementedError.new
    end

    def do_start
      raise NotImplementedError.new
    end

    def do_process_options(options)
      raise NotImplementedError.new
    end

    def do_get_option_table
      raise NotImplementedError.new
    end

    def self.start
      app = self.new
      begin
        app.start
      rescue IncompatibleDBError => e
        eprintf("%s", e.message)
      end
    end
  end
end
