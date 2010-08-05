require "fileutils"

def remove(iPath)
	if ( File.exist?( iPath ) )
		File.delete( iPath )
	end
end

path = "gonzui.rb"
path = File.join( curr_srcdir, path )
remove( path )


