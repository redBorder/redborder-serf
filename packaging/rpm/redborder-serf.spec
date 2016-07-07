Name: redborder-serf
Version: %{__version}
Release: %{__release}%{?dist}
BuildArch: noarch
Summary: Package for redborder serf initscripts and configuration.

License: AGPL 3.0
URL: https://github.com/redBorder/redborder-common
Source0: %{name}-%{version}.tar.gz

Requires: serf

%description
%{summary}

%prep
%setup -qn %{name}-%{version}

%build

%install
mkdir -p %{buildroot}/etc/serf
install -D -m 0644 serf.service %{buildroot}/usr/lib/systemd/system/serf.service
install -D -m 0644 first.json %{buildroot}/etc/serf/00first.json

%pre

%files
%defattr(0644,root,root)
/etc/serf/00first.json
/usr/lib/systemd/system/serf.service
%doc

%changelog
* Thu Jul 07 2016 Juan J. Prieto <jjprieto@redborder.com> - 1.0.0-1
- first spec version
