#
# extractor.rb - a package extraction library
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

require 'find'
require 'ftools'

module Gonzui
  class ExtractorError < GonzuiError; end

  module Extractor
    extend Util
    ExtractorRegistry = {}

    module_function
    def extnames
      ExtractorRegistry.keys
    end

    def get_archive_extname(file_name)
      ExtractorRegistry.keys.each {|extname|
        pattern = Regexp.new(Regexp.quote(extname) + '$') #'
        return extname if pattern.match(file_name)
      }
      return nil
    end

    def supported_file?(file_name)
      ExtractorRegistry.include?(get_archive_extname(file_name))
    end

    def suppress_archive_extname(file_name)
      extname = get_archive_extname(file_name)
      pattern = Regexp.new(Regexp.quote(extname) + '$') #'
      return file_name.gsub(pattern, "")
    end

    def new(config, file_name)
      extname = get_archive_extname(file_name)
      if klass = ExtractorRegistry[extname]
        return klass.new(config, file_name)
      else
        raise ExtractorError.new("#{extname}: unsupported archive")
      end
    end

    def register(klass)
      klass.commands.each {|command|
        return unless command_exist?(command)
      }
      klass.extnames.each {|extname|
        assert(!ExtractorRegistry.include?(extname))
        ExtractorRegistry[extname] = klass
      }
    end
  end

  class AbstractExtractor
    include Util
    include TemporaryDirectoryUtil

    def initialize(config, file_name)
      @config = config
      @archive_directory = nil
      @file_name = file_name
      @extracted_files = []
      raise ExtractorError.new("#{@file_name}: no such file") unless 
        File.file?(@file_name)
      set_temporary_directory(config.temporary_directory)
    end

    private
    def run_extract_command(command_line, file_name)
	  cd = "cd"
	  cd << " /d" if (/mswin|mingw|bccwin/ =~ RUBY_PLATFORM)
      command_line = sprintf("#{cd} %s && %s", 
                             shell_escape(self.temporary_directory),
                             command_line)
      status = system(command_line)
      raise ExtractorError.new("#{file_name}: unable to extract a file") if 
        status == false
    end

    # Well-mannered archive doesn't scatter files when extracted.
    def has_single_directory?(directory)
      entries = Dir.entries_without_dots(directory)
      entries.length == 1 and 
        File.directory?(File.join(directory, entries.first))
    end

    # Gather scattered files in to a single directory.
    def arrange_extracted_files
      package_name = 
        Extractor.suppress_archive_extname(File.basename(@file_name))
      new_directory = File.join(self.temporary_directory, package_name)

      if has_single_directory?(self.temporary_directory)
        entries = Dir.entries_without_dots(self.temporary_directory)
        entry = entries.first
        old_directory = File.join(self.temporary_directory, entry)
        if old_directory != new_directory
          File.rename(old_directory, new_directory)
        end
        return
      end

      entries  = Dir.entries_without_dots(self.temporary_directory)
      tmp_name = entries.max || 'tmp'
      tmp_name += '.tmp'
      tmp_directory = File.join(self.temporary_directory, tmp_name)

      File.mkpath(tmp_directory)

      entries.each {|entry|
        from = File.join(self.temporary_directory, entry)
        to   = File.join(tmp_directory, entry)
        File.rename(from, to)
      }
      File.rename(tmp_directory, new_directory)
    end

    def raise_error_if_empty_archive?
      entries = Dir.entries_without_dots(self.temporary_directory)
      raise ExtractorError.new("#{@file_name}: empty package") if 
        entries.length == 0
    end

    def get_archive_directory
      unless has_single_directory?(self.temporary_directory)
        raise "#{@file_name}: is not well extracted"
      end
      entry = Dir.entries_without_dots(self.temporary_directory).first
      return File.join(self.temporary_directory, entry)
    end

    public
    def extract
      prepare_temporary_directory
      begin
        do_extract
        FileUtils.fix_permission(self.temporary_directory)
        raise_error_if_empty_archive?
        arrange_extracted_files
        return get_archive_directory
      rescue ExtractorError => e
        clean_temporary_directory
        raise(e)
      end
    end

    def clean
      clean_temporary_directory
    end
  end

  class TarGzipExtractor < AbstractExtractor
    def self.commands
      ["tar", "gzip"]
    end

    def self.extnames
      [".tar.gz", ".tgz"]
    end

    def do_extract
      command_line = sprintf("gzip -d -c %s | tar xf -",
                             shell_escape(File.expand_path(@file_name)))
      run_extract_command(command_line, @file_name)
    end

    Extractor.register(self)
  end

  class TarBzip2Extractor < AbstractExtractor
    def self.commands
      ["tar", "bzip2"]
    end

    def self.extnames
      [".tar.bz2"]
    end

    def do_extract
      command_line = sprintf("bzip2 -d -c %s | tar xf -",
                             shell_escape(File.expand_path(@file_name)))
      run_extract_command(command_line, @file_name)
    end

    Extractor.register(self)
  end

  class TarCompressExtractor < AbstractExtractor
    def self.commands
      ["tar", "uncompress"]
    end

    def self.extnames
      [".tar.Z"]
    end

    def do_extract
      command_line = sprintf("uncompress -c %s | tar xf -",
                             shell_escape(File.expand_path(@file_name)))
      run_extract_command(command_line, @file_name)
    end

    Extractor.register(self)
  end

  class ZipExtractor < AbstractExtractor
    def self.commands
      ["unzip"]
    end

    def self.extnames
      [".zip"]
    end

    def do_extract
      command_line = sprintf("unzip -q %s",
                             shell_escape(File.expand_path(@file_name)))
      run_extract_command(command_line, @file_name)
    end

    Extractor.register(self)
  end

  class TarExtractor < AbstractExtractor
    def self.commands
      ["tar"]
    end

    def self.extnames
      [".tar"]
    end

    def do_extract
      command_line = sprintf("tar xf %s",
                             shell_escape(File.expand_path(@file_name)))
      run_extract_command(command_line, @file_name)
    end

    Extractor.register(self)
  end

  class LZHExtractor < AbstractExtractor
    def self.commands
      ["lha"]
    end

    def self.extnames
      [".lzh"]
    end

    def do_extract
      command_line = sprintf("lha -eq %s",
                             shell_escape(File.expand_path(@file_name)))
      run_extract_command(command_line, @file_name)
    end

    Extractor.register(self)
  end

  class SRPMExtractor < AbstractExtractor
    def self.commands
      ["rpm", "rpmbuild"]
    end

    def self.extnames
      [".src.rpm"]
    end

    RPMTemporaryDirectories = ["BUILD", "SOURCES", "SPECS"]
    def prepare_rpm_directories
      RPMTemporaryDirectories.each {|dirname| 
        Dir.mkdir(File.join(self.temporary_directory, dirname))
      }
    end

    def clean_rpm_directories
      RPMTemporaryDirectories.each {|dirname| 
        path = File.join(self.temporary_directory, dirname)
        FileUtils.rm_rff(path)
      }
    end

    def find_spec_file(spec_directory)
      base_name = Dir.entries_without_dots(spec_directory).first
      raise ExtractorError.new("spec file not found") unless 
        File.extname(base_name) == ".spec"
      return File.join(spec_directory, base_name)
    end

    def do_extract_internal
      options = "--nodeps --rmsource"
      common  = sprintf("rpmbuild --define '_topdir %s' %s",
                        self.temporary_directory, options)
      command_line = sprintf("rpm --define '_topdir %s' -i %s",
                             self.temporary_directory,
                             shell_escape(File.expand_path(@file_name)))
      status = system(command_line)
      raise ExtractorError.new("rpm command failed") if status == false
      spec_directory = File.join(self.temporary_directory, "SPECS")
      spec_file_name = find_spec_file(spec_directory)
      command_line =  sprintf("%s -bp %s", common, shell_escape(spec_file_name))
      # FIXME: --target=i686 is a kludge for ExclusiveArch
      command_line << sprintf("|| %s --target=i686 -bp %s",
                              common, shell_escape(spec_file_name))
      unless @config.verbose
        command_line = sprintf("(%s) >/dev/null 2>&1", command_line)
      end
      run_extract_command(command_line, @file_name)

      build_directory = File.join(self.temporary_directory, "BUILD")
      unless has_single_directory?(build_directory)
        raise ExtractorError.new("BUILD should contain a single directory")
      end
      base_name = Dir.entries_without_dots(build_directory).first
      package_name = File.basename(@file_name, ".src.rpm")
      src  = File.join(build_directory, base_name)
      dest = File.join(self.temporary_directory, package_name)
      File.rename(src, dest)

      unless FileTest.exist?(File.join(dest, File.basename(spec_file_name)))
        FileUtils.mv(spec_file_name, dest)
      end
    end

    def do_extract
      prepare_rpm_directories
      begin
        do_extract_internal
      ensure
        clean_rpm_directories
      end
    end

    Extractor.register(self)
  end
end
