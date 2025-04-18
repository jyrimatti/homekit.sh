#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p dash nix yq jq ncurses which
. ./prelude
set -eu

mkdir -p "$HOMEKIT_SH_STORE_DIR"
mkdir -p "$HOMEKIT_SH_CACHE_DIR"
mkdir -p "$HOMEKIT_SH_RUNTIME_DIR"
mkdir -p "$HOMEKIT_SH_ACCESSORIES_DIR"

if [ -n "${HOMEKIT_SH_NIX_OVERRIDE:-}" ]; then
    mkdir -p "$HOMEKIT_SH_STORE_DIR/nix-override"
    ln -fs "$(which dash)" "$HOMEKIT_SH_STORE_DIR/nix-override/nix-shell"
fi

mkdir -p "$BKT_CACHE_DIR"
mkdir -p "$HOMEKIT_SH_RUNTIME_DIR/sessions"
mkdir -p "$HOMEKIT_SH_RUNTIME_DIR/sent_events"

dash ./util/bridges.sh \
    | while read -r port bridge username; do {
        if [ "$bridge" != "" ]; then
            bridge="/$bridge"
        fi
        mkdir -p "${HOMEKIT_SH_STORE_DIR}${bridge}/pairings"
        mkdir -p "${HOMEKIT_SH_STORE_DIR}${bridge}/sent_events"

        if [ "$port" != "" ]; then
            if [ ! -f "${HOMEKIT_SH_STORE_DIR}${bridge}/AccessoryLTPK" ]; then
                ln -s "${HOMEKIT_SH_STORE_DIR}/AccessoryLTPK" "${HOMEKIT_SH_STORE_DIR}${bridge}/AccessoryLTPK"
            fi
            if [ ! -f "${HOMEKIT_SH_STORE_DIR}${bridge}/AccessoryLTSK" ]; then
                ln -s "${HOMEKIT_SH_STORE_DIR}/AccessoryLTSK" "${HOMEKIT_SH_STORE_DIR}${bridge}/AccessoryLTSK"
            fi
        fi

        if [ ! -f "${HOMEKIT_SH_STORE_DIR}${bridge}/dns-txt" ]; then
            echo "c#=1 id=${username:-$HOMEKIT_SH_USERNAME} md=homekit.sh s#=1 sf=1 ci=2 pv=1.1 ff=0" > "$HOMEKIT_SH_STORE_DIR${bridge}/dns-txt"
        fi
      } done
