#
# util.rb - utility functions
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

require 'find'
require 'fileutils'
require 'iconv'
require 'benchmark'
require 'uri'
require 'thread'

module URI
  module_function
  def path_join(*fragments)
    if fragments.empty?
      return ""
    elsif fragments.length == 1
      return fragments.fileutils
    else
      return fragments.map {|fragment| fragment.chomp("/") }.join("/")
    end
  end

  def from_path(path)
    path = File.expand_path(path)
    if (/^([a-zA-Z]:|\\\\)(.*)$/ =~ path)
      u = URI::Generic.new( "file", nil, $1, nil, nil, $2, nil, nil, nil, false )
      def u.to_s
        self.host + self.path
      end
      return u
    else
      path = path.gsub(/#{Regexp.quote(File::SEPARATOR)}/, "/")
      return URI.parse(sprintf("file://%s", path))
    end
  end

  def for_apt(package_name)
    URI.parse(sprintf("apt-get://apt-get/%s", package_name))
  end

  def for_cvs(repository, mozule)
    if m = /^(?:(.+?)@)?(.+)$/.match(repository)
      prefix = m[1]
      root = m[2]
      str = sprintf("cvs://%s?module=%s", root, mozule)
      str << sprintf("&prefix=%s", prefix) if prefix
      return URI.parse(str)
    else
      raise "malformed repository: #{repository}"
    end
  end

  def for_svn(repository, mozule)
    uri = URI.parse(repository)
    query = sprintf("module=%s", mozule)
    uri = URI.from_path(repository) unless uri.absolute?
    # replace schemes other than "svn" such as "file" and "http"
    # with "svn" and preserve the original scheme in a query.
    unless uri.scheme == "svn"
      query << sprintf("&original_scheme=%s", uri.scheme)
      uri.scheme = "svn"
    end
    uri.query = query
    return uri
  end

  def for_git(repository)
    uri = URI.parse(repository)
    uri = URI.from_path(repository) unless uri.absolute?
    return uri
  end
end

class NullObject
  def initialize(*args)
  end
  def method_missing(name, *args)
  end
end

module FileUtils
  module_function
  def chmod_r(mode, *paths)
    Find.find(*paths) {|path|
      File.chmod(mode, path) if !File.symlink?(path)
    }
  end

  def fix_permission(directory)
    Find.find(directory) {|file_name|
      stat = File.lstat(file_name)
      if stat.directory?
        if stat.mode & 0777 != (stat.mode | 0700) & 0755
          File.chmod((stat.mode | 0700) & 0755, file_name)
        end
      elsif stat.file?
        if stat.mode & 0666 != (stat.mode | 0600) & 0644
          File.chmod((stat.mode | 0600) & 0644, file_name)
        end
      end
    }
  end

  def rm_rff(path)
    fix_permission(path)
    rm_rf(path)
  end
end

class String
  def clear
    replace("")
  end

  def prechop
    if m = /^./m.match(self)
      return m.post_match
    else
      return ""
    end
  end

  def substring(range)
    raise unless range.exclude_end?
    self[range.first, range.last - range.first]
  end

  def line_range(byteno)
    head = if self[byteno] == ?\n
             byteno
           else
             (self.rindex(?\n, byteno) or -1) + 1
           end
    tail = (self.index(?\n, byteno) or  self.length)
    return (head...tail)
  end

  def each_line_range(byteno, ncontexts)
    raise unless block_given?
    lines = []
    center = self.line_range(byteno)
    lines.push([0, center])

    head = center.first
    ncontexts.times {|i|
      pos = head - 2
      pos += 1 if self[pos] == ?\n # empty line
      break if pos <= 0
      range = self.line_range(pos)
      head = range.first
      lines.unshift([0 - i - 1, range])
    }

    tail = center.last
    ncontexts.times {|i|
      pos = tail + 1
      break if pos >= self.length
      range = self.line_range(pos)
      tail = range.last
      lines.push([i + 1, range])
    }

    lines.each {|lineno_offset, range|
      yield(lineno_offset, range)
    }
  end

  def untabify
    new = ""
    self.each_line {|line|
      true while line.gsub!(/\t+/) { 
        ' ' * ($&.length * 8 - $`.length % 8)  #`)
      }
      new << line
    }
    return new
  end
end

class Dir
  def self.entries_without_dots(directory)
    entries(directory).find_all {|e| e != "." and e != ".." }
  end

  def self.all_files(directory)
    file_names = []
    Find.find(directory) {|file_name|
      next unless File.file?(file_name)
      file_names.push(file_name)
    }
    return file_names.sort!
  end
end

class File
  # FIXME: Use pathname.rb ?
  def self.relative_path(path, base)
    return "" if path == base
    re_terminated_with_path_separator = /#{File::SEPARATOR}$/
    sep = if re_terminated_with_path_separator.match(base)
            ""
          else
            File::SEPARATOR
          end
    pattern = sprintf("^%s%s", Regexp.quote(base), sep)
    path.sub(Regexp.new(pattern), "")
  end

  def self.any_exist?(path)
    File.exist?(path) or File.symlink?(path)
  end
end

class Array
  def devide(n)
    if self.empty?
      []
    elsif self.length < n
      [self]
    else
      (0...(self.length / n)).map {|x| self[x * n, n] }
    end
  end
end

module Gonzui
  module Util
    module_function
    def program_name
      File.basename($0)
    end

    def windows?
      /-(mswin32|cygwin|mingw|bccwin)/.match(RUBY_PLATFORM)
    end

    def unix?
      not windows?
    end

    def command_exist?(command)
      paths = (ENV['PATH'] or "").split(File::PATH_SEPARATOR)
      paths.each {|path|
        return true if File.executable?(File.join(path, command))
		# windows
        return true if File.executable?(File.join(path, command + ".exe"))
      }
      return false
    end

    class CommandNotFoundError < GonzuiError; end 
    def require_command(command)
      raise CommandNotFoundError.new("#{command}: command not found") unless 
        command_exist?(command)
      return true
    end

    def shell_escape(file_name)
      if (/mswin|mingw|bccwin/ =~ RUBY_PLATFORM)
        fn = file_name
        fn.gsub!(/["]/, "")
        if /^\w+:\/\// =~ fn
          # file://c/temp => file:///c:/temp
          fn.sub!(/^file:\/\/\/?(\w)\//, "file:///\\1:/")
        else
          fn.gsub!(/[\/]/, "\\")
        end
        '"' + fn + '"'
      else
        '"' + file_name.gsub(/([$"\\`])/, "\\\\\\1") + '"'
      end
    end

    def wprintf(format, *args)
      STDERR.printf(program_name + ": " + format + "\n", *args)
    end

    def eprintf(format, *args)
      wprintf(format, *args)
      exit(1)
    end

    @@verbosity = false
    def set_verbosity(verbosity)
      @@verbosity = verbosity
    end

    def vprintf(format, *args)
      printf(format + "\n", *args) if @@verbosity
    end

    def commify(number)
      numstr = number.to_s
      true while numstr.sub!(/^([-+]?\d+)(\d{3})/, '\1,\2')
      return numstr
    end

    def format_bytes(bytes)
      if bytes < 1024
        sprintf("%dB", bytes)
      elsif bytes < 1024 * 1000 # 1000kb
        sprintf("%.1fKB", bytes.to_f / 1024)
      elsif bytes < 1024 * 1024 * 1000  # 1000mb
        sprintf("%.1fMB", bytes.to_f / 1024 / 1024)
      else
        sprintf("%.1fGB", bytes.to_f / 1024 / 1024 / 1024)
      end
    end

    def benchmark
      result = nil
      Benchmark.bm {|x|
        x.report { 
          result = yield 
        }
      }
      return result
    end

    # Use a global mutex to make the method thread-safe
    $protect_from_signals_mutex = Mutex.new
    def protect_from_signals
      $protect_from_signals_mutex.synchronize {
        interrupted = false
        previous_handlers = {}
        signals = ["INT", "TERM"]

        signals.each {|signal|
          previous_handlers[signal] = trap(signal) { interrupted = true }
        }
        yield
        previous_handlers.each {|signal, handler|
          trap(signal, handler)
        }
        raise Interrupt if interrupted
      }
    end

    class AssertionFailed < StandardError; end

    def assert_non_nil(object)
      raise AssertionFailed.new if object.nil?
    end

    def assert_not_reached
      raise AssertionFailed.new
    end

    def assert_equal(expected, value)
      raise AssertionFailed.new unless expected == value
    end

    def assert_equal_all(*values)
      first = values.first
      unless values.all? {|value| first == value }
        raise AssertionFailed.new
      end
    end

    def assert(bool)
      raise AssertionFailed.new unless bool
    end
  end

  module UTF8
    Preference = ["iso-2022-jp", "euc-jp", "utf-8", "shift_jis", 
      "cp932", "iso-8859-1", "ascii"]

    module_function
    def set_preference(preference)
      Preference.replace(preference)
    end

    def to_utf8(str)
      return str, "us-ascii" if /\A[\r\n\t\x20-\x7e]*\Z/n.match(str)
      Preference.each {|name|
        begin
          return Iconv.conv("UTF-8", name, str), name
        rescue Iconv::IllegalSequence, ArgumentError
        end
      }
      return str, "binary"
    end
  end

  module TemporaryDirectoryUtil
    attr_reader :temporary_directory

    def prepare_temporary_directory
      raise "temporary directory not set" if temporary_directory.nil?
      raise "#{temporary_directory}: exists" if 
        File.any_exist?(temporary_directory)
      File.mkpath(temporary_directory)
    end

    def clean_temporary_directory
      raise "temporary directory not set" if temporary_directory.nil?
      FileUtils.rm_rff(temporary_directory)
    end

    def set_temporary_directory(directory)
      base_name = ["gonzui", "tmp", Process.pid, self.object_id].join(".")
      @temporary_directory = File.join(directory, base_name)
    end
  end
end

