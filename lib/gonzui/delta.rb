#
# delta.rb - byte-oriented delta compression implementation
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

require 'gonzui/delta.so'

module Gonzui
  module DeltaDumper
    PACK_FORMAT = "w*"

    module_function
    def dump_tuples(klass, list)
      encode_tuples(list, klass::DeltaSize, klass::UnitSize)
      return list.pack(PACK_FORMAT)
    end

    def undump_tuples(klass, dump)
      list = dump.unpack(PACK_FORMAT)
      decode_tuples(list, klass::DeltaSize, klass::UnitSize)
      #
      # Make an array of arrays for convinence of the caller
      # [1,2,3,4,5,6] => [[1,2], [3,4], [5,6] if UnitSize is 2
      #
      values = (0...(list.length / klass::UnitSize)).map {|i| 
        list[i * klass::UnitSize, klass::UnitSize]
      }
      return values
    end

    def dump_fixnums(list)
      encode_fixnums(list).pack(PACK_FORMAT)
    end

    def undump_fixnums(dump)
      decode_fixnums(dump.unpack(PACK_FORMAT))
    end

    alias dump_ids dump_fixnums
    alias undump_ids undump_fixnums
    module_function :dump_ids, :undump_ids
  end
end
