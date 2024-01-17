#!/bin/sh

servicedir=$HOME/.config/systemd/user
configdir=$HOME/.config/homekit.sh

scriptdir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if [ ! -d "$configdir" ]; then
    echo "Creating $configdir..."
    mkdir -p "$configdir"
fi

if [ ! -d "$configdir/accessories" ]; then
    echo "Creating $configdir/accessories for your accessories..."
    mkdir -p "$configdir/accessories"
fi
cp "$scriptdir/config/bridge.toml" "$configdir/accessories/"

if [ ! -d "$servicedir" ]; then
    echo "Creating $servicedir..."
    mkdir -p "$servicedir"
fi

if [ ! -f "$configdir/environment" ]; then
    echo "Creating $configdir/environment for custom configuration (see $scriptdir/config/environment for defaults)..."
    touch "$configdir/environment"
fi

echo "Creating $servicedir/homekit.sh.service..."
cat > "$servicedir/homekit.sh.service" << EOF
[Unit]
Description=Homekit.sh
After=syslog.target network.target avahi-daemon.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c '. /etc/profile.d/nix.sh; $scriptdir/start.sh prepare'
RemainAfterExit=yes
TimeoutStartSec=600

ProtectSystem=strict
ProtectHome=read-only
ProtectKernelTunables=true
RestrictRealtime=true
RestrictSUIDSGID=true
PrivateTmp=true

StandardOutput=journal
StandardError=journal
SyslogIdentifier=homekit.sh
SyslogLevel=warning
WorkingDirectory=$scriptdir
Environment='HOMEKIT_SH_LOGGING=syslog'

[Install]
WantedBy=default.target
RequiredBy=network.target
EOF

cat > "$servicedir/homekit.sh-broadcast.service" << EOF
[Unit]
Description=Homekit.sh Broadcast
PartOf=homekit.sh.service
After=homekit.sh.service
Wants=avahi-daemon.service

[Service]
ExecStart=/bin/sh -c '. /etc/profile.d/nix.sh; $scriptdir/broadcast.sh'
Type=simple
Restart=always

ProtectSystem=strict
ProtectHome=read-only
ProtectKernelTunables=true
RestrictRealtime=true
RestrictSUIDSGID=true
PrivateTmp=true

StandardOutput=journal
StandardError=journal
SyslogIdentifier=homekit.sh
SyslogLevel=warning
WorkingDirectory=$scriptdir
Environment='HOMEKIT_SH_LOGGING=syslog'

[Install]
WantedBy=homekit.sh.service
EOF

cat > "$servicedir/homekit.sh-monitor.service" << EOF
[Unit]
Description=Homekit.sh Monitor
PartOf=homekit.sh.service
After=homekit.sh.service

[Service]
ExecStart=/bin/sh -c '. /etc/profile.d/nix.sh; $scriptdir/monitor.sh'
Type=simple
Restart=always

ProtectSystem=strict
ProtectHome=read-only
ProtectKernelTunables=true
RestrictRealtime=true
RestrictSUIDSGID=true
PrivateTmp=true

StandardOutput=journal
StandardError=journal
SyslogIdentifier=homekit.sh
SyslogLevel=warning
WorkingDirectory=$scriptdir
Environment='HOMEKIT_SH_LOGGING=syslog'

[Install]
WantedBy=homekit.sh.service
EOF

cat > "$servicedir/homekit.sh-poller.service" << EOF
[Unit]
Description=Homekit.sh Poller
PartOf=homekit.sh.service
After=homekit.sh.service

[Service]
ExecStart=/bin/sh -c '. /etc/profile.d/nix.sh; $scriptdir/poller.sh'
Type=simple
Restart=always

ProtectSystem=strict
ProtectHome=read-only
ProtectKernelTunables=true
RestrictRealtime=true
RestrictSUIDSGID=true
PrivateTmp=true

StandardOutput=journal
StandardError=journal
SyslogIdentifier=homekit.sh
SyslogLevel=warning
WorkingDirectory=$scriptdir
Environment='HOMEKIT_SH_LOGGING=syslog'

[Install]
WantedBy=homekit.sh.service
EOF

cat > "$servicedir/homekit.sh-serve.service" << EOF
[Unit]
Description=Homekit.sh Serve
PartOf=homekit.sh.service
After=homekit.sh.service

[Service]
ExecStart=/bin/sh -c '. /etc/profile.d/nix.sh; $scriptdir/start.sh'
Type=simple
Restart=always
TasksMax=infinity

ProtectSystem=strict
ProtectHome=read-only
ProtectKernelTunables=true
RestrictRealtime=true
RestrictSUIDSGID=true
PrivateTmp=true

StandardOutput=journal
StandardError=journal
SyslogIdentifier=homekit.sh
SyslogLevel=warning
WorkingDirectory=$scriptdir
Environment='HOMEKIT_SH_LOGGING=syslog'

[Install]
WantedBy=homekit.sh.service
EOF

echo "Reloading systemd config..."
systemctl --user daemon-reload

echo "Enabling homekit.sh.service..."
systemctl --user enable homekit.sh homekit.sh-broadcast homekit.sh-monitor homekit.sh-poller homekit.sh-serve

echo "Enabling user process lingering for $USER..."
loginctl enable-linger "$USER"

echo "Done! Homekit.sh will now start on boot."
echo "You can start it manually with 'systemctl --user start homekit.sh.service'"
echo "Follow logs with 'journalctl -f -t homekit.sh'"