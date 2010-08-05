#
# gettext.rb - a simple gettext-like module
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  module GetText
    def gettext(text)
      return text unless @gettext_catalog
      return (@gettext_catalog[text] or text)
    end
    alias :_ :gettext

    def gettext_noop(text)
      text
    end
    alias :N_ :gettext_noop

    def set_catalog(catalog)
      @gettext_catalog = catalog
    end

    def load_catalog(file_name)
      return eval(File.read(file_name))
    end
  end

  class CatalogRepository
    include GetText

    def initialize(directory)
      @catalogs = {}
      Dir.entries(directory).each {|entry|
        file_name = File.join(directory, entry)
        if m = /^catalog\.([\w.-]+)$/.match(File.basename(file_name))
          lang = m[1]
          catalog = load_catalog(file_name)
          @catalogs[lang] = catalog
        end
      }
      @catalogs["en"] = Hash.new {|h, k| k }
    end

    public
    def choose(lang_name)
      @catalogs[lang_name]
    end

    def each
      @catalogs.each {|lang_name, catalog|
        yield(lang_name, catalog)
      }
    end
  end


  class CatalogValidator
    def initialize(source_file_name, messages)
      @source_file_name  = source_file_name
      @gettext_catalog = messages
      @error_messages = []
    end
    attr_reader :error_messages

    def read_file_with_numbering(file_name)
      content = ''
      File.open(file_name).each_with_index {|line, idx|
        lineno = idx + 1
        content << line.gsub(/\bN?_\(/, "_[#{lineno}](")
      }
      content
    end

    def collect_messages(content)
      messages = []
      while content.sub!(/\bN?_\[(\d+)\]\(("(?:\\"|.)*?").*?\)/m, "")
        lineno  = $1.to_i
        message = eval($2)
        messages.push([lineno, message])
      end
      messages
    end

    def validate
      @gettext_catalog or return
      content = read_file_with_numbering(@source_file_name)
      messages = collect_messages(content)
      messages.each {|lineno, message|
        translated_message = @gettext_catalog[message]
        if not translated_message
          message = 
            sprintf("%s:%d: %s", @source_file_name, lineno, message.inspect)
          @error_messages.push(message)
        elsif message.count("%") != translated_message.count("%")
          message = sprintf("%s:%d: %s => # of %% mismatch.",
                            @source_file_name, 
                            lineno, message.inspect, translated_message)
          @error_messages.push(message)
        end
      }
    end

    def ok?
      @error_messages.empty?
    end
  end
end

if __FILE__ == $0
  include Gonzui
  include Gonzui::GetText

  def main
    if ARGV.length < 2
      puts "usage: ruby catalog-validator.rb <catalog directory> <source...>"
      exit
    end

    catalog_directory = ARGV.shift
    catalog_repository = CatalogRepository.new(catalog_directory)

    ok = true
    catalog_repository.each {|lang_name, catalog|
      set_catalog(catalog)
      ARGV.each {|source_file|
        validator = CatalogValidator.new(source_file, catalog)
        validator.validate
        validator.error_messages.each {|message|
          printf("%s: %s\n", lang_name, message)
        }
        ok = (ok and validator.ok?)
      }
    }
    if ok then exit else exit(1) end
  end

  main
end
