require "fileutils"

winstandalone = config( 'winstandalone' )

path = "gonzui.rb.in"
path = File.join( curr_srcdir, path )
text = File.read( path )

e = {
	:VERSION => "1.3", 
	:SYSCONFDIR => ".", 
	:PKGDATADIR => "share/gonzui", 
	:GONZUI_URI => "http://gonzui.sourceforge.net/", 
	:HTTP_PORT => "46984"
}
e.merge( {
	:SYSCONFDIR => %q;#{File.dirname($0)};, 
	:PKGDATADIR => %q;#{File.join(File.dirname($0), "..", "share", "gonzui")};, 
} ) if ( winstandalone )

e.keys.each do |k|
	text.gsub!( /%#{k.to_s}%/, e[k] )
end

path = "gonzui.rb"
path = File.join( curr_srcdir, path )
open( path, "w" ) do |h|
	h.write( text )
end


