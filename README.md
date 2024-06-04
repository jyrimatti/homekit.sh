# Homekit.sh - Simple accessory bridge for Apple Homekit

Prerequisites
-------------
- get a computer (e.g. a server or a Raspberry Pi)
- install [Nix](https://nixos.org/download/)

Install
-------

```
./install.sh
systemctl --user start homekit.sh.service
```

Homekit.sh configuration
------------------------

Runtime environment can be customized in file `~/.config/homekit.sh/environment`.
See the default values in `./config/environment`.

You should add there at least the following:
```
# Unique identifier for the bridge. Just make up one.
# Change this if you want the bridge at some point to be seen as a different bridge by Apple Homekit.
HOMEKIT_SH_USERNAME="AA:AA:AA:AA:AA:00"

# Pincode for Apple Homekit. Just make up one.
# Must be of format: nnn-nn-nnn
HOMEKIT_SH_PINCODE="123-45-678"
```

In addition to limited number of predefined services with predefined characteristics, Apple Homekit also supports custom services and characteristics. These are defined in directories `./config/services/` and `./config/characteristics/`. You can add your own, but note that Apple Home application won't be able to manage them.

Accessory configuration
-----------------------

Accessories are defined in `~/.config/homekit.sh/accessories/`. You can clone Git repos directly here.

An accessory is configured in file `~/.config/homekit.sh/accessories/<some_accessory>/homekit.sh-config.toml` using [TOML](https://toml.io/en/) syntax. Please refer to `./accessory.schema.json` for the schema.

Apple Homekit seems to interact with different accessories of a bridge serially. Especially slow accessories will slow down everything. It is therefore recommended to configure most accessories as their own child bridges, resulting in Apple Homekit interacting them in parallel. This is done by including the following properties in the accessory configuration:

```toml
bridge = <some unique bridge name>
port = <some unique port for the bridge>
username = <some unique username for the bridge>
```

Every accessory must have at least AccessoryInformation service:
```toml
[[services]]
type = "AccessoryInformation"

[services.characteristics]
Identify = {} # don't change this!
Manufacturer = "Jyri-Matti Lähteenmäki"
Model = "My accessory model"
Name = "My accessory name"
SerialNumber = "AA:AA:AA:AA:AA:01" # some unique serial number
FirmwareRevision = "100.1.1" # whatever
```

Then add all the services with characteristics you have:

```toml
[[services]]
type = "TemperatureSensor"

[services.characteristics]
Name = "Room temperature"
ConfiguredName = "Room temperature"
timeout = 5
[services.characteristics.CurrentTemperature]
minValue = -99999
maxValue = 99999
minStep = 0.001
polling = 5
cmd = "cd myaccessory; ./cmd/room_temperature.sh"
```

Default values for characteristics can be overridden. Make sure to use only valid values.

The `cmd` property is the shell command used to get and set the value of the characteristic. The script is executed relative to `~/.config/homekit.sh/accessories/` directory. The script must output a valid value to stdout.

- One of strings `Get` or `Set` is given as the first argument.
- Second and third argument are (some yet undefined) identifiers for service and characteristic respectively.
- When setting, the new value is given as the fourth argument.

Apple Homekit events are supported by defining `polling`. It can be set either for a characteristic or for the whole service (enabling polling for all of its characteristics). The script is run every `polling` seconds, and whenever the value changes, it is sent as an event back to Apple Homekit.

`timeout` can be defined for a characteristic or for the whole service. If the script takes longer than `timeout` seconds to execute, it will be interrupted.

Logging
-------

Three logging backends are supported:

- stderr
- syslog
- log4sh

Syslog is used by default if Homekit.sh is used as a systemd service.

If started manually, defaults to stderr.

User interface
--------------

Just use the Apple Home application, or your favorite 3rd party app.

Alternatively, direct your web browser to `http://<hostname>:<bridgeport>/ui/`. Still work in progress.

Architecture
------------

TODO

Troubleshooting
---------------

You can reset the pairing with Apple Homekit (*Warning!* This will remove all your accessories from Homekit and you will have to re-pair and reconfigure everything!):
```
./reset.sh
```

If you suspect a bug related to caching, you can clear all homekit.sh caches with:
```
./clear_caches.sh
```

If Apple Homekit doesn't seem to add your services with their correct names, be sure to include characteristic `ConfiguredName` in addition to `Name`.

Apple Homekit doesn't seem to support "unknown" values, but for some reason the `/accessories` endpoint must still return some value for all characteristics. Homekit.sh will return the default value or minimum value if one is defined, otherwise some sensible value (false, 0, "", valid-values[0]). You might want to allow ridiculous values as a minimum (for example -99999 for a temperature) to recognize unknown values in applications.

Apple Homekit `/prepare`, `/resource` and `secure-message` -endpoints are not implemented.
