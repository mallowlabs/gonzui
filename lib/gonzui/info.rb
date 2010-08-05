#
# info.rb - information classes
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  module BytenoMixin
    def end_byteno
      byteno + length
    end

    def range
      byteno ... (byteno + length)
    end
  end

  WordInfo = Struct.new(:word_id, :path_id, 
                        :seqno, :byteno, :type_id, :type, :lineno)
  class WordInfo
    include BytenoMixin

    # dump info
    DeltaSize = 2
    UnitSize = 3

    def match?(target_type)
      target_type == :all or target_type == self.type
    end
  end

  DigestInfo = Struct.new(:byteno, :length, :type_id, :type)
  class DigestInfo
    include BytenoMixin

    # dump info
    DeltaSize = 1
    UnitSize = 3
  end

  ContentInfo = Struct.new(:size, :mtime, :itime, 
                           :format_id, :license_id, 
                           :nlines, :indexed_p)
  class ContentInfo
    extend Util
    PACK_FORMAT = "w*"

    def self.load(dump)
      info = self.new(*dump.unpack(PACK_FORMAT))
      info.indexed_p = if info.indexed_p == 1 then true else false end
      return info
    end

    def self.dump(size, mtime, itime, format_id, 
                  license_id,  nlines, indexed_p)
      indexed_p = if indexed_p then 1 else 0 end
      # FIXME: It could happen for some cases.
      if mtime < 0
        vprintf("minus mtime found: %d", mtime)
        mtime = Time.now.to_i
      end
      [size, mtime, itime, format_id, 
        license_id, nlines, indexed_p].pack(PACK_FORMAT)
    end

    def indexed?
      self.indexed_p
    end
  end

  Occurrence = Struct.new(:byteno, :lineno, :length)
  class Occurrence
    include BytenoMixin
  end
end
