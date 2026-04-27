Name:           cache-api
Version:        1.0.0
Release:        1%{?dist}
Summary:        Cache Proxy API Service
License:        MIT
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
Requires:       python3, python3-pip

%description
Flask-based caching proxy API service for caching layer project.

%prep
%setup -q

%install
# Создаём директории
mkdir -p %{buildroot}/usr/local/bin
mkdir -p %{buildroot}/etc/cache-api
mkdir -p %{buildroot}/etc/systemd/system

# Копируем файлы
install -m 755 cache-api.py %{buildroot}/usr/local/bin/cache-api.py
install -m 644 config.yaml %{buildroot}/etc/cache-api/config.yaml

# Создаём systemd unit прямо в spec
cat > %{buildroot}/etc/systemd/system/cache-api.service << 'EOF'
[Unit]
Description=Cache API Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/cache-api.py
Environment=CONFIG_PATH=/etc/cache-api/config.yaml
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

%post
pip3 install flask redis requests pyyaml --quiet
systemctl daemon-reload

%files
/usr/local/bin/cache-api.py
/etc/cache-api/config.yaml
/etc/systemd/system/cache-api.service

%changelog
* Mon Apr 27 2026 devops <devops@example.com> - 1.0.0-1
- Initial release
