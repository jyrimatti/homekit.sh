#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.05-small -p dash nix shellspec yq nodejs yajsv parallel coreutils bc ncurses sqlite "pkgs.callPackage ./jq-1.7.nix {}" "pkgs.callPackage ./modbus_cli.nix {}"
. ./prefs
. ./logging
. ./profiling
set -eu

prefix="${1:-}"

shellspec --shell dash --fail-fast --format documentation -e PATH="~/.local/nix-override:$PATH" spec/$prefix*