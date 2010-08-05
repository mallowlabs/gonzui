#
# remover.rb - remove contents from gonzui.db
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org> 
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

module Gonzui
  class RemoverError < GonzuiError; end

  class Remover < AbstractUpdater
    private
    def do_task_name
      "removed"
    end

    public
    def remove_package(package_name)
      raise RemoverError.new("#{package_name}: package not found") unless
        @dbm.has_package?(package_name)
      ncontents = @dbm.get_ncontents_in_package(package_name)

      pbar = make_progress_bar(package_name, ncontents)
      package_id = @dbm.get_package_id(package_name)
      @dbm.get_path_ids(package_id).each {|path_id|
        normalized_path = @dbm.get_path(path_id)
        deindex_content(normalized_path)
        pbar.inc
      }
      pbar.finish
      @npackages += 1
    end
  end
end
