#
# monitor.rb - performance monitor
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  class PerformanceMonitor
    @@performance_counters = {}

    def initialize
      @start_time = Time.now
      @elapsed_time = nil
      @finished_p = false
    end

    private
    def finish
      @elapsed_time = Time.now - @start_time
      @finished_p = true
    end

    def build_label(m, name)
      case m
      when Class
        m.to_s + "#" + name.to_s
      when Module
        m.to_s + "." + name.to_s
      end
    end

    public
    def self.[] (label)
      @@performance_counters[label]
    end

    def empty?
      @@performance_counters.empty?
    end

    def profile(m, name)
      label = build_label(m, name)
      if !@@performance_counters[label]
        @@performance_counters[label] = PerformanceCounter.new
        case m
        when Class
          eval <<"End"
          class #{m}
            alias orig_#{name} #{name}
            @@pc_#{name} = Gonzui::PerformanceMonitor["#{label}"]
            # redefine with profiler
            def #{name}(*args, &block)
              @@pc_#{name}.enter
              begin
                orig_#{name}(*args, &block)
              ensure
                @@pc_#{name}.leave
              end
            end
          end
End
        when Module
          eval <<"End"
          module #{m}
            alias orig_#{name} #{name}
            module_function :orig_#{name}
            # redefine with profiler
            def #{name}(*args, &block)
              pc = Gonzui::PerformanceMonitor["#{label}"]
              pc.enter
              begin
                orig_#{name}(*args, &block)
              ensure
                pc.leave
              end
            end
            module_function :#{name}
          end
End
        end
      end
    end

    def heading
      return Gonzui::PerformanceCounter.heading
    end

    def format(primary_label, *labels)
      finish unless @finished_p

      label = build_label(*primary_label)
      primary_pc = Gonzui::PerformanceMonitor[label]
      return "" if primary_pc.nil?

      summary = primary_pc.summary(label, 1, @elapsed_time)
      labels.each {|label|
        label = build_label(*label)
        pc = Gonzui::PerformanceMonitor[label]
        next if pc.nil?
        summary  << pc.summary(label, 2, @elapsed_time)
        primary_pc.exclude(pc)
      }
      summary << primary_pc.rest_summary(:other, 2, @elapsed_time)
      summary << "\n"
      return summary
    end
  end

  class PerformanceCounter
    def initialize
      @count = 0
      @time_enter = 0
      @time_total = 0
      @time_subtotal = 0
      @times_enter = 0
      @times_total = Struct::Tms.new(0, 0, 0, 0)
      @times_subtotal = Struct::Tms.new(0, 0, 0, 0)
    end

    def enter
      @time_enter = Time.now
      @times_enter = Process.times
      @count += 1
    end

    def leave
      @time_total += Time.now - @time_enter
      times = Process.times
      @times_total.utime += times.utime - @times_enter.utime
      @times_total.stime += times.stime - @times_enter.stime
    end

    def time
      @time_total
    end

    def utime
      @times_total.utime
    end

    def stime
      @times_total.stime
    end

    def exclude(pc)
      @time_subtotal += pc.time
      @times_subtotal.utime += pc.utime
      @times_subtotal.stime += pc.stime
    end

    def self.heading
      sprintf("%-32s %8s   %6s  %6s  %6s\n",
              "", "count", "utime", "stime", "real")
    end

    def summary(label, indent, elapsed)
      sprintf("%-32s %8d  %6.2fs %6.2fs %6.2fs (%6.2f%%)\n",
              " " * indent + label, @count,
              @times_total.utime, @times_total.stime,
              @time_total, @time_total * 100 / elapsed)
    end

    def rest_summary(label, indent, elapsed)
      time = @time_total - @time_subtotal
      utime = @times_total.utime - @times_subtotal.utime
      stime = @times_total.stime - @times_subtotal.stime
      sprintf("%-32s %8s  %6.2fs %6.2fs %6.2fs (%6.2f%%)\n",
              " " * indent + label.to_s, '',
              utime, stime, time, time * 100 / elapsed)
    end
  end
end
