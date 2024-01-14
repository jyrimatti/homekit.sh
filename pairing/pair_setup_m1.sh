#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash jq python3Packages.srp python3Packages.tlv8
. ./prefs
. ./log/logging
. ./profiling
set -eu

logger_trace 'pairing/pair_setup_m1.sh'

storePath="$1"
setupCode="$2"

. ./util/tlv.sh

serverPrivateKey=$(./pairing/generate_random_bytes.sh 32) || {
    logger_error 'Server key generation failed'
    exit 1
}
echo -n "$serverPrivateKey" | ./util/hex2bin.sh > "$storePath/serverPrivateKey"

accessorySRPPublicKey=$(echo -n "$serverPrivateKey" | ./pairing/srp_get_challenge.sh "Pair-Setup" "$setupCode" "$storePath/salt" "$storePath/verifier") || {
    logger_error "Server key generation failed"
    exit 1
}
salt=$(cat "$storePath/salt" | ./util/bin2hex.sh)

response="{\"$TLV_STATE\": $TLV_M2, \"$TLV_PUBLIC_KEY\": \"$accessorySRPPublicKey\", \"$TLV_SALT\": \"$salt\"}"
jq -n "$response" | ./util/tlv_encode.sh

logger_debug "M2 response: $response"
