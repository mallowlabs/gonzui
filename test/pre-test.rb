
dn = "/dev/null"
dn = "nul" if (/mswin|mingw|bccwin/ =~ RUBY_PLATFORM)
apt   = ( system( "apt-get --version 2> #{dn} > #{dn}" ) ? true : false )
cvs   = ( system( "cvs --version 2> #{dn} > #{dn}" ) ? true : false )
git   = ( system( "git --version 2> #{dn} > #{dn}" ) ? true : false )
grep  = ( system( "grep --version 2> #{dn} > #{dn}" ) ? true : false )
svn   = ( system( "svn --version 2> #{dn} > #{dn}" ) ? true : false )
zip   = ( system( "zip --version 2> #{dn} > #{dn}" ) ? true : false )
unzip = ( system( "unzip -v 2> #{dn} > #{dn}" ) ? true : false )
gzip  = ( system( "gzip --version 2> #{dn} > #{dn}" ) ? true : false )
bzip2 = ( system( "bzip2 --help 2> #{dn} > #{dn}" ) ? true : false )
tar   = ( system( "tar --version 2> #{dn} > #{dn}" ) ? true : false )
#dummy = ( system( "ruby -e '' 2> #{dn}" ) ? true : false )

path = srcfile( "_external_tools.rb" )
open( path, "w" ) do |w|
	w.write( <<-EOS )
APT_ = #{apt}
CVS_ = #{cvs}
GIT_ = #{git}
GREP_ = #{grep}
SVN_ = #{svn}
ZIP_ = #{zip}
UNZIP_ = #{unzip}
GZIP_ = #{gzip}
BZIP2_ = #{bzip2}
TAR_ = #{tar}
ARC_ = ( ZIP_ && UNZIP_ && GZIP_ && BZIP2_ && TAR_ )
	EOS
end


