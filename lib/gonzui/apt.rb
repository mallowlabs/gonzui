#
# apt.rb - an interface library for apt
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  class AptGetError < GonzuiError; end

  module AptGet
    extend Util

    AptGetRegistry = {}

    module_function
    def available?
      begin
        require_command("apt-get")
        return true
      rescue CommandNotFoundError
        return false
      end
    end

    def get_apt_type
      require_command("apt-get")
      apt_type = :unknown
      IO.popen("apt-get --version").each {|line|
        if m = /^\*Ver: Standard \.(.*)$/.match(line)
          apt_type = m[1].intern
        end
      }
      return apt_type
    end

    def new(config, package_name)
      apt_type = get_apt_type
      if klass = AptGetRegistry[apt_type]
        return klass.new(config, package_name)
      else
        raise AptGetError.new("#{apt_type}: unsupported apt type")
      end
    end

    def register(klass)
      assert(!AptGetRegistry.include?(klass.apt_type))
      AptGetRegistry[klass.apt_type] = klass
    end
  end

  class AbstractAptGet
    include Util
    include TemporaryDirectoryUtil

    def initialize(config, package_name)
      @config = config
      @package_name = package_name
      @apt_options = ""
      @cleaning_procs = []
      set_temporary_directory(config.temporary_directory)
    end

    def run_apt_get
	  cd = "cd"
	  cd << " /d" if (/mswin|mingw|bccwin/ =~ RUBY_PLATFORM)
      command_line = sprintf("#{cd} %s && apt-get -qq %s source %s >/dev/null 2>&1",
                             shell_escape(self.temporary_directory),
                             @apt_options,
                             shell_escape(@package_name))
      status = system(command_line)
      raise AptGetError.new("#{@package_name}: unable to get sources") if
        status == false
    end

    def extract_package
      NotImplementedError.new("should be implemented in a sub class")
    end

    def add_cleaning_proc(proc)
      @cleaning_procs.push(proc)
    end

    public
    def extract
      prepare_temporary_directory
      run_apt_get
      return extract_package
    end

    def clean
      @cleaning_procs.each {|proc| proc.call }
      clean_temporary_directory
    end
  end

  class DebAptGet < AbstractAptGet
    def self.apt_type
      :deb
    end

    def find_archive(directory)
      Dir.entries_without_dots(directory).map {|entry|
        File.join(directory, entry)
      }.find {|file_name|
        Extractor.supported_file?(file_name)
      }
    end

    def find_deb_source_directory
      entries  = Dir.entries_without_dots(self.temporary_directory)
      directory = entries.map {|entry|
        File.join(self.temporary_directory, entry)
      }.find {|path|
        File.directory?(path)
      }
      raise AptGetError.new("#{@package_name}: source directory not found") if
        directory.nil?
      return directory
    end

    def remove_deb_files
      Dir.entries(self.temporary_directory).each {|entry|
        file_name = File.join(self.temporary_directory, entry)
        File.unlink(file_name) if File.file?(file_name)
      }
    end

    def contains_single_tarball?(directory)
      entries = Dir.entries_without_dots(directory)
      entries.delete("debian")
      entries.delete("CVS") # some packages have it
      entries.length == 1 and Extractor.supported_file?(entries.first)
    end

    def extract_package
      remove_deb_files
      source_directory = find_deb_source_directory
      if contains_single_tarball?(source_directory)
        archive_file_name = find_archive(source_directory)
        extractor = Extractor.new(@config, archive_file_name)
        add_cleaning_proc(lambda{ extractor.clean_temporary_directory })
        return extractor.extract
      else
        return source_directory
      end
    end

    AptGet.register(self)
  end

  class RPMAptGet < AbstractAptGet
    def self.apt_type
      :rpm
    end

    def initialize(config, package_name)
      super(config, package_name)
      @apt_options = "-d"
    end

    def srpm_file?(file_name)
      /\.src\.rpm$/.match(file_name)
    end

    def find_srpm_file
      entries = Dir.entries_without_dots(self.temporary_directory)
      raise AptGetError.new("#{@package_name}: download failed") if
        entries.length != 1

      candidate = entries.first
      raise AptGetError.new("#{@package_name}: SRPM not found") unless
        srpm_file?(candidate)
      return File.join(self.temporary_directory, candidate)
    end

    # FIXME: It cannot handle multiple tar balls in a single
    # package like FC2's emacs including emacs, Mule-UCS, .
    private
    def extract_package
      srpm_file_name = find_srpm_file
      extractor = Extractor.new(@config, srpm_file_name)
      add_cleaning_proc(lambda{ extractor.clean_temporary_directory })
      return extractor.extract
    end

    AptGet.register(self)
  end
end
