require "fileutils"

def remove(iPath)
	if ( File.exist?( iPath ) )
		File.delete( iPath )
	end
end

files = %W!db import remove search server update!
files.each do |name|
	path = "gonzui-#{name}.rb"
	path = File.join( curr_srcdir, path )
	remove( path )
end


