Summary: foo is a test program
Name: foo
Version: 0.1
Release: 1
License: GPL
Group: Applications/Text
Source0: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
foo is a test program.

%prep
%setup -q

%build

%install
rm -rf $RPM_BUILD_ROOT

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%doc


%changelog
* Wed Sep  1 2004 Satoru Takabayashi <satoru@namazu.org> - 
- Initial build.

