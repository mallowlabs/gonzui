#
# vcs.rb - simple interface to version control systems
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  class VCSError < GonzuiError; end

  class AbstractVCS
    include Util

    def initialize(config, root, mozule)
      @config = config
      @root = root
      @mozule = mozule
    end

    private
    def run_command(command_line, message)
      printf("running %s...\n", message) unless @config.quiet
      dn = "/dev/null"
      dn = "nul" if (/mswin|mingw|bccwin/ =~ RUBY_PLATFORM)
      command_line += ">#{dn} 2>&1" unless @config.verbose
      status = system(command_line)
      raise VCSError.new("command execution failed") if status == false
    end

    public
    def extract
      File.mkpath(@config.cache_directory)
      output_directory = File.join(@config.cache_directory, @mozule)
      if not File.exist?(output_directory)
        do_checkout(output_directory)
      elsif File.directory?(output_directory)
        do_update(output_directory)
      else
        raise VCSError.new("#{output_directory}: obstacle found")
      end
      return output_directory
    end

    def clean
    end
  end

  class CVS < AbstractVCS
    def initialize(config, root, mozule)
      require_command("cvs")
      super(config, root, mozule)
    end

    def do_checkout(output_directory)
      Dir.chdir(@config.cache_directory) {
        command_line = sprintf("cvs -z3 -d %s co -P %s", 
                               shell_escape(@root),
                               shell_escape(@mozule))
        run_command(command_line, "cvs checkout")
      }
    end

    def do_update(output_directory)
      Dir.chdir(output_directory) {
        run_command("cvs -z3 update -dP", "cvs update")
      }
    end

    def do_extract
      File.mkpath(@config.cache_directory)
      output_directory = File.join(@config.cache_directory, @mozule)
      if File.exist?(output_directory)
        run_cvs_update(output_directory)
      else
        run_cvs_checkout
      end
      return output_directory
    end
  end

  class Subversion < AbstractVCS
    def initialize(config, root, mozule)
      require_command("svn")
      super(config, root, mozule)
    end

    def do_checkout(output_directory)
      Dir.chdir(@config.cache_directory) {
        command_line = sprintf("svn co %s %s", 
                               shell_escape(@root),
                               shell_escape(@mozule))
        run_command(command_line, "svn checkout")
      }
    end

    def do_update(output_directory)
      Dir.chdir(output_directory) {
        run_command("svn update","svn update")
      }
    end
  end

  class Git < AbstractVCS
    def initialize(config, root, mozule = nil)
      require_command("git")
      mozule = File.basename(URI.parse(root).path, ".git") unless mozule
      super(config, root, mozule)
    end

    def do_checkout(output_directory)
      Dir.chdir(@config.cache_directory) {
        command_line = sprintf("git clone %s",
                               shell_escape(@root))
        run_command(command_line, "git clone")
      }
    end

    def do_update(output_directory)
      Dir.chdir(output_directory) {
        run_command("git pull","git pull")
      }
    end
  end
end
