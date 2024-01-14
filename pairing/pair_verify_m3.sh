#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash jq xxd bc
. ./prefs
. ./log/logging
. ./profiling
set -eu

logger_trace 'pairing/pair_verify_m3.sh'

pairingStorePath="$1"
sessionStorePath="$2"
tlvjson="$3"

. ./util/tlv.sh

logger_debug "M4: Verify Finish Response"

encrypted="$(echo -n "$tlvjson" | jq -r ".[\"$TLV_ENCRYPTED_DATA\"]")"
# last 16 bytes are authTag
messageData="$(echo -n "$encrypted" | head -c "$(echo "${#encrypted}-32" | bc)")"
authTagData="$(echo -n "$encrypted" | tail -c 32)"

iOSDevicePublicKey="$(cat "$sessionStorePath/iOSDevicePublicKey" | dash ./util/bin2hex.sh)"
AccessoryPublicKey="$(cat "$sessionStorePath/AccessoryPublicKey" | dash ./util/bin2hex.sh)"
sharedSecret="$(cat "$sessionStorePath/sharedSecret" | dash ./util/bin2hex.sh)"

# Derive the symmetric session encryption key, SessionKey, from the Curve25519 shared secret by using HKDF-SHA-512 
SessionKey=$(echo -n "$sharedSecret" | dash ./pairing/hkdf.sh "Pair-Verify-Encrypt-Salt" "Pair-Verify-Encrypt-Info") || {
    logger_error 'HKDF failed'
    exit 1
}

# Verify the iOSdevice's authTag, which is appended to the encryptedData and contained within the kTLVType_EncryptedData TLV item, against encryptedData.
# Decrypt the sub-TLV in encryptedData.
subTLVhex="$(echo -n "$messageData" | ./pairing/decrypt_and_verify.sh "PV-Msg03" "$SessionKey" "$authTagData" || {
        logger_error 'Error while decrypting and verifying M3 subTlv'
        jq -n "{\"$TLV_STATE\": $TLV_M4, \"$TLV_ERROR\": \"$TLV_ERROR_AUTHENTICATION\"}" | ./util/tlv_encode.sh
        exit 2
})"
subTLV="$(echo -n "$subTLVhex" | ./util/tlv_decode.sh)"

iOSDevicePairingIDhex="$(echo -n "$subTLV" | jq -r ".[\"$TLV_IDENTIFIER\"]")"
iOSDevicePairingID="$(echo -n "$iOSDevicePairingIDhex" | ./util/hex2bin.sh)"
iOSDeviceSignature="$(echo -n "$subTLV" | jq -r ".[\"$TLV_SIGNATURE\"]")"

# Use the iOS deviceʼs Pairing Identifier, iOSDevicePairingID, to look up the iOS deviceʼs long-term public key, iOSDeviceLTPK, in its list of paired controllers.
test -f "$pairingStorePath/$iOSDevicePairingID/iOSDevicePairingID" || {
    logger_info "Client iOSDevicePairingID $iOSDevicePairingID not found -> not paired"
    jq -n "{\"$TLV_STATE\": $TLV_M4, \"$TLV_ERROR\": \"$TLV_ERROR_AUTHENTICATION\"}" | ./util/tlv_encode.sh
    exit 4
}

iOSDeviceInfo="${iOSDevicePublicKey}${iOSDevicePairingIDhex}${AccessoryPublicKey}"

# Use Ed25519 to verify iOSDeviceSignature using iOSDeviceLTPK against iOSDeviceInfo contained in the decrypted sub-TLV
echo -n "$iOSDeviceInfo" | dash ./pairing/verify.sh "$pairingStorePath/$iOSDevicePairingID/iOSDeviceLTPK" "$iOSDeviceSignature" || {
    logger_error 'Invalid iOSDeviceSignature'
    jq -n "{\"$TLV_STATE\": $TLV_M4, \"$TLV_ERROR\": \"$TLV_ERROR_AUTHENTICATION\"}" | ./util/tlv_encode.sh
    exit 4
}

AccessoryToControllerKey=$(echo -n "$sharedSecret" | dash ./pairing/hkdf.sh "Control-Salt" "Control-Read-Encryption-Key") || {
    logger_error 'HKDF failed'
    exit 1
}
echo -n "$AccessoryToControllerKey" | dash ./util/hex2bin.sh > "$sessionStorePath/AccessoryToControllerKey"

ControllerToAccessoryKey=$(echo -n "$sharedSecret" | dash ./pairing/hkdf.sh "Control-Salt" "Control-Write-Encryption-Key") || {
    logger_error 'HKDF failed'
    exit 1
}
echo -n "$ControllerToAccessoryKey" | dash ./util/hex2bin.sh > "$sessionStorePath/ControllerToAccessoryKey"

# Send the response to the iOS device with the following TLV items:
response="{\"$TLV_STATE\": $TLV_M4}"
jq -n "$response" | ./util/tlv_encode.sh

logger_debug "M4 response: $response"
