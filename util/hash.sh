#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -I channel:nixos-23.05-small -p bash
set -euo pipefail
PS4='+ $(date "+%T.%3N ($LINENO) ")'

cksum -a crc | cut -d' ' -f1