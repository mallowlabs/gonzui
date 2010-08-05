require 'rubygems'
begin
  require 'redgreen'
rescue LoadError
end
$LOAD_PATH << File.dirname(__FILE__) # require "test"
require 'stringio'
#require 'rbconfig.rb' # omajinai
require 'test/unit'
require File.dirname(__FILE__) + '/../lib/gonzui'
