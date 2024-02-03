#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash jq
. ./prelude
set -eu

logger_trace 'pairing/pair_setup_m3.sh'

storePath="$1"
tlvjson="$2"

. ./util/tlv.sh

iOSDeviceSRPPublicKey="$(echo -n "$tlvjson" | jq -r ".[\"$TLV_PUBLIC_KEY\"]")"
iOSDeviceSRPProof="$(echo -n "$tlvjson" | jq -r ".[\"$TLV_PROOF\"]")"

# Use the iOS deviceʼs SRP public key to compute the SRP shared secret key
echo -n "$iOSDeviceSRPPublicKey" | ./util/hex2bin.sh > "$storePath/iOSDeviceSRPPublicKey"

serverPrivateKey="$(cat "$storePath/serverPrivateKey" | ./util/bin2hex.sh)"
verifier="$(cat "$storePath/verifier" | ./util/bin2hex.sh)"
salt="$(cat "$storePath/salt" | ./util/bin2hex.sh)"

# Verify the iOS device's SRP proof 
# Generate the accessory-side SRP proof
accessorySideSRPProof=$(echo -n "$iOSDeviceSRPProof" | ./pairing/srp_verify_session.sh "Pair-Setup" "$verifier" "$salt" "$serverPrivateKey" "$iOSDeviceSRPPublicKey" "$storePath/srpSharedSecret") || {
    logger_error "Invalid iOSDeviceSRPProof"
    # If verification fails, the accessory must respond with the following TLV items
    jq -n "{\"$TLV_STATE\": $TLV_M4, \"$TLV_ERROR\": $TLV_ERROR_AUTHENTICATION}" | ./util/tlv_encode.sh
    exit 2
}

response="{\"$TLV_STATE\": $TLV_M4, \"$TLV_PROOF\": \"$accessorySideSRPProof\"}"
jq -n "$response" | ./util/tlv_encode.sh

logger_debug "M4 response: $response"
