require 'gonzui'
require 'fileutils'
include FileUtils

def gnu_make?
  message = IO.popen("make --version").read
  /^GNU/.match(message)
end

module TestUtil
  FOO_FILES   = ["bar.c", "bar.h", "foo.c", "Makefile" ].sort
  FOO_C_FILES = FOO_FILES.find_all {|x| /\.[ch]$/.match(x) }
  FOO_SYMBOLS = ["bar", "foo", "main", "printf"]
  FOO_PACKAGE = "foo-0.1"
  FOO_TGZ     = File.join("foo", FOO_PACKAGE + ".tar.gz")

  @@make_options = if gnu_make?
                     "--quiet --no-print-directory"
                   else
                     ""
                   end

  def add_package(config)
    importer = Gonzui::Importer.new(config)
    url = URI.from_path(FOO_TGZ)
    importer.import(url)
    importer.finish
  end

  def make_db(config)
    remove_db(config)
    make_archives
    importer = Gonzui::Importer.new(config)
    url = URI.from_path(FOO_TGZ)
    importer.import(url)
    importer.finish
  end

  def remove_db(config)
    rm_rf(config.db_directory)
  end

  def make_dist_tree
    system("cd foo && make #{@@make_options} -f Makefile.foo dist-tree")
  end

  def make_clean
    system("cd foo && make #{@@make_options} -f Makefile.foo clean")
  end

  def make_archives
    Gonzui::Util.require_command("zip")
    Gonzui::Util.require_command("tar")
    Gonzui::Util.require_command("gzip")
    Gonzui::Util.require_command("bzip2")
    system("cd foo && make #{@@make_options} -f Makefile.foo dist")
    system("cd foo && make #{@@make_options} -f Makefile.foo dist-poor")
  end

  def cvsroot
    File.expand_path("tmp.cvsroot")
  end

  def make_cvs
    remove_cvs
    make_dist_tree
    assert(Gonzui::Util.command_exist?("cvs"))
    Dir.mkdir(cvsroot)
    command_line = sprintf("cvs -d %s init", shell_escape(cvsroot))
    system(command_line)
    command_line = sprintf("cd %s && ", shell_escape("foo/#{FOO_PACKAGE}"))
    command_line << sprintf("cvs -d %s import -m '' foo gonzui-test test", shell_escape(cvsroot))
    system(command_line)
  end

  def remove_cvs
    FileUtils.rm_rf(cvsroot)
  end

  def svnroot
    File.expand_path("tmp.svnroot")
  end

  def make_svn
    remove_svn
    make_dist_tree
    assert(Gonzui::Util.command_exist?("svn"))
    assert(Gonzui::Util.command_exist?("svnadmin"))
    svnroot_uri = sprintf("file:///%s", svnroot)
    Dir.mkdir(svnroot)
    command_line = sprintf("svnadmin create %s", shell_escape(svnroot))
    system(command_line)
    command_line = sprintf("cd %s && ", shell_escape("foo/#{FOO_PACKAGE}"))
    command_line << sprintf("svn -q import -m '' %s", shell_escape(svnroot_uri))
    system(command_line)
    return svnroot_uri
  end

  def remove_svn
    FileUtils.rm_rf(svnroot)
  end

  def gitroot
    File.expand_path("tmp.gitroot")
  end

  def make_git
    remove_git
    make_dist_tree
    assert(Gonzui::Util.command_exist?("git"))
    Dir.mkdir(gitroot)
    command_line = sprintf("git --git-dir %s init", shell_escape(gitroot))
    system(command_line)
    command_line = sprintf("cd %s && ", shell_escape("foo/#{FOO_PACKAGE}"))
    command_line << sprintf("git --git-dir %s --work-tree . add . && ", shell_escape(gitroot))
    command_line << sprintf("git --git-dir %s --work-tree . commit -m 'import'", shell_escape(gitroot))
    system(command_line)
    return gitroot
  end

  def remove_git
    FileUtils.rm_rf(gitroot)
  end
end

if ENV['MAKEFLAGS'] # be quiet in a make process.
  ARGV.unshift("--verbose=s")
end
