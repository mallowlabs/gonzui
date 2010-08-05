require "fileutils"

winstandalone = config( 'winstandalone' )
files = %W!db import remove search server update!

script = <<-EOS
$: << File.join( File.dirname( $0 ), '..', 'lib' )
$: << File.join( File.dirname( $0 ), '..', 'lib', '#{Config::CONFIG["sitearch"]}' )
ENV['PATH'] += File::PATH_SEPARATOR + File.dirname( $0 )
EOS
files.each do |name|
	path = "gonzui-#{name}.in"
	path = File.join( curr_srcdir, path )
	text = File.read( path )
	if ( winstandalone )
		text.gsub!( /^#\s*%LOADPATH%$/, script )
	end
		text.gsub!( /%RUBY%/, "/usr/bin/env ruby" )
	path = "gonzui-#{name}"
	path << ".rb" if ( /msvcrt|mingw|bccwin/ =~ Config::CONFIG["sitearch"] )
	path = File.join( curr_srcdir, path )
	open( path, "w" ) do |h|
		h.write( text )
	end
end


