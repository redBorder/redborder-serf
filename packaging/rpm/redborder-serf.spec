Name: redborder-serf
Version: %{__version}
Release: %{__release}%{?dist}
BuildArch: noarch
Summary: Package for redborder serf initscripts and configuration.

License: AGPL 3.0
URL: https://github.com/redBorder/redborder-common
Source0: %{name}-%{version}.tar.gz

Requires: serf arp-scan rvm redborder-common

%description
%{summary}

%prep
%setup -qn %{name}-%{version}

%build

%install
mkdir -p %{buildroot}/etc/serf
mkdir -p %{buildroot}/usr/lib/redborder/bin
install -D -m 0644 resources/serf.service %{buildroot}/usr/lib/systemd/system/serf.service
install -D -m 0644 resources/serf-join.service %{buildroot}/usr/lib/systemd/system/serf-join.service
cp resources/*.rb %{buildroot}/usr/lib/redborder/bin
cp resources/*.sh %{buildroot}/usr/lib/redborder/bin

%pre

%files
%defattr(0644,root,root)
/usr/lib/systemd/system/serf.service
/usr/lib/systemd/system/serf-join.service
%defattr(0755,root,root)
/usr/lib/redborder/bin
%doc

%changelog
* Thu Jul 07 2016 Juan J. Prieto <jjprieto@redborder.com> - 1.0.0-1
- first spec version
