root = File.dirname( __FILE__ )
foodir = File.join( root, "foo" )

lst = %w|
foo-0.1.tar.bz2
foo-0.1.tar.gz
foo-0.1.zip
foo-0.1p.tar.bz2
foo-0.1p.tar.gz
foo-0.1p.zip
|
lst.each do |e|
	path = File.join( foodir, e )
	if ( File.file?( path ) )
		File.delete( path )
	end
end

lst = %w|
foo.c
bar.c
bar.h
Makefile
|
path = File.join( foodir, "foo-0.1" )
if ( File.directory?( path ) )
	lst.each do |e|
		f = File.join( path, e )
		if ( File.file?( f ) )
			File.delete( f )
		end
	end
	Dir.rmdir( path )
end

lst = %w|
_external_tools.rb|
lst.each do |e|
	path = File.join( root, e )
	if ( File.file?( path ) )
		File.delete( path )
	end
end


