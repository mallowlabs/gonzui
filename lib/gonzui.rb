# -*- mode: ruby -*-
#
# gonzui - a source code search engine.
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#
#require 'rubygems'

$LOAD_PATH << "lib"
$LOAD_PATH << "ext"

module Gonzui
  VERSION    = "1.2"
  SYSCONFDIR = "."
  PKGDATADIR = File.join(__FILE__, "..", "..", "data", "gonzui")
  GONZUI_URI = "http://gonzui.sourceforge.net"
  HTTP_PORT  = 46984
  class GonzuiError < StandardError; end
end

require "gonzui/util"
require "gonzui/gettext"

begin # for Rake task
require 'gonzui/autopack'
require 'gonzui/delta'
require "gonzui/texttokenizer"
rescue LoadError
end

require "gonzui/dbm"
require "gonzui/bdbdbm"
require "gonzui/monitor"

require "gonzui/content"
require "gonzui/fetcher"
require "gonzui/updater"
require "gonzui/importer"
require "gonzui/remover"
require "gonzui/vcs"

require "gonzui/apt"
require "gonzui/config"
require "gonzui/deindexer"
require "gonzui/extractor"
require "gonzui/indexer"
require "gonzui/info"
require "gonzui/license"
require "gonzui/logger"
require 'gonzui/searcher'
require 'gonzui/searchquery'
require 'gonzui/searchresult'


