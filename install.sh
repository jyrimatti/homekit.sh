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

echo "Creating empty $configdir/environment for overrides..."
if [ ! -f "$configdir/environment" ]; then
    {
        echo "# systemd specifiers:"
        echo "# %S XDG_STATE_HOME"
        echo "# %C XDG_CACHE_HOME"
        echo "# %E XDG_CONFIG_HOME"
        echo "# %t XDG_RUNTIME_DIR" 
    } > "$configdir/environment"
fi

echo "Creating $servicedir/homekit.sh.service..."
cat > "$servicedir/homekit.sh.service" << EOF
[Unit]
Description=Homekit.sh
After=syslog.target network.target avahi-daemon.service

[Service]
ExecStart=$scriptdir/start.sh
Type=simple
ProtectSystem=strict
ProtectHome=read-only
PrivateTmp=true
Restart=always
StandardOutput=journal
StandardError=journal
WorkingDirectory=$scriptdir
Environment='HOMEKIT_SH_LOGGING=syslog' 'HOMEKIT_SH_ENV_SET=true'
EnvironmentFile=$scriptdir/config/environment
EnvironmentFile=$configdir/environment

[Install]
WantedBy=default.target
RequiredBy=network.target
EOF

echo "Reloading systemd config..."
systemctl --user daemon-reload

echo "Enabling homekit.sh.service..."
systemctl --user enable homekit.sh.service

echo "Done! Homekit.sh will now start on boot."