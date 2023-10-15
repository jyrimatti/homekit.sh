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
Wants=avahi-daemon.service
After=syslog.target network.target avahi-daemon.service

[Service]
ExecStartPre=/bin/sh -c '. /etc/profile.d/nix.sh; $scriptdir/start.sh prepare'
ExecStart=/bin/sh -c '. /etc/profile.d/nix.sh; $scriptdir/start.sh'
Type=simple

ProtectSystem=strict
ProtectHome=read-only
ProtectKernelTunables=true
MemoryDenyWriteExecute=true
RestrictRealtime=true
RestrictSUIDSGID=true
PrivateTmp=true

Restart=always
StandardOutput=journal
StandardError=journal
WorkingDirectory=$scriptdir
Environment='HOMEKIT_SH_LOGGING=syslog'

[Install]
WantedBy=default.target
RequiredBy=network.target
EOF

echo "Reloading systemd config..."
systemctl --user daemon-reload

echo "Enabling homekit.sh.service..."
systemctl --user enable homekit.sh.service

echo "Done! Homekit.sh will now start on boot."
echo "You can start it manually with 'systemctl --user start homekit.sh.service'"
echo "Follow logs with 'journalctl -f -t homekit.sh'"