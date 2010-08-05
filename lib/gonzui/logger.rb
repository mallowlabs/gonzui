# -*- mode: ruby -*-
#
# logger.rb - logger implementation
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  class Logger
    def initialize(out = nil, verbose_p = false)
      @verbose_p = verbose_p
      @out = case out
             when String
               File.open(out, "a")
             when NilClass
               STDERR
             else
               out
             end
      @out.sync = true
      @monitor = nil
    end
    attr_writer :monitor

    private
    def puts_log(format, *arguments)
      time = Time.now.strftime("%Y-%m-%dT%H:%M:%S")
      message = ""
      message << time << " " << sprintf(format, *arguments) << "\n"
      @out << message
      @monitor << message if @monitor
    end

    public
    def log(format, *arguments)
      puts_log(format, *arguments)
    end

    def vlog(format, *arguments)
      puts_log(format, *arguments) if @verbose_p
    end
  end
end
