#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash jq bc coreutils
. ./prefs
. ./log/logging
. ./profiling
set -eu

logger_trace 'pairing/pair_setup_m5.sh'

AccessoryPairingID="$1"
storePath="$2"
pairingStorePath="$3"
tlvjson="$4"

. ./util/tlv.sh

encrypted="$(echo -n "$tlvjson" | jq -r ".[\"$TLV_ENCRYPTED_DATA\"]")"
# last 16 bytes are authTag
messageData="$(echo -n "$encrypted" | head -c "$(echo "${#encrypted}-32" | bc)")"
authTagData="$(echo -n "$encrypted" | tail -c 32)"

srpSharedSecret="$(cat "$storePath/srpSharedSecret" | ./util/bin2hex.sh)"

# Derive the symmetric session encryption key, SessionKey,from the SRP shared secret by using HKDF-SHA-512 with the following parameters:
sessionKey="$(echo -n "$srpSharedSecret" | dash ./pairing/hkdf.sh "Pair-Setup-Encrypt-Salt" "Pair-Setup-Encrypt-Info")" || {
    logger_error 'HKDF failed'
    exit 1
}

plaintext="$(echo -n "$messageData" | ./pairing/decrypt_and_verify.sh "PS-Msg05" "$sessionKey" "$authTagData")" || {
    logger_error "Error while decrypting and verifying M5 subTlv"
    # If verification/decryption fails, the accessory must respond with the following TLV items:
    jq -n "{\"$TLV_STATE\": $TLV_M4, \"$TLV_ERROR\": $TLV_ERROR_AUTHENTICATION}" | ./util/tlv_encode.sh
    exit 2
}

# Derive iOSDeviceX from the SRP shared secret by using HKDF-SHA-512
iOSDeviceX="$(echo -n "$srpSharedSecret" | dash ./pairing/hkdf.sh "Pair-Setup-Controller-Sign-Salt" "Pair-Setup-Controller-Sign-Info")" || {
    logger_error 'HKDF failed'
    exit 1
}

# decode the client payload and pass it on to the next step
M5Packet="$(echo -n "$plaintext" | ./util/tlv_decode.sh)"
iOSDevicePairingIDhex="$(echo -n "$M5Packet" | jq -r ".[\"$TLV_IDENTIFIER\"]")"
iOSDevicePairingID="$(echo -n "$iOSDevicePairingIDhex" | ./util/hex2bin.sh)"
iOSDeviceLTPK="$(echo -n "$M5Packet" | jq -r ".[\"$TLV_PUBLIC_KEY\"]")"
iOSDeviceSignature="$(echo -n "$M5Packet" | jq -r ".[\"$TLV_SIGNATURE\"]")"

# Construct iOSDeviceInfo by concatenating iOSDeviceX with the iOSdevice's Pairing Identifier, iOSDevicePairingID, from the decrypted sub-TLV and the iOS deviceʼs long-term public key, iOSDeviceLTPK from the decrypted sub-TLV
iOSDeviceInfo="${iOSDeviceX}${iOSDevicePairingIDhex}${iOSDeviceLTPK}"

mkdir -p "$pairingStorePath/$iOSDevicePairingID"
echo -n "$iOSDevicePairingID" | ./util/hex2bin.sh > "$pairingStorePath/$iOSDevicePairingID/iOSDevicePairingID"
echo -n "$iOSDeviceLTPK" | ./util/hex2bin.sh > "$pairingStorePath/$iOSDevicePairingID/iOSDeviceLTPK"
echo -n "01" | ./util/hex2bin.sh > "$pairingStorePath/$iOSDevicePairingID/iOSDevicePermissions" # Admin. TODO: implement proper permissions

# Use Ed25519 to verify the signature of the constructed iOSDeviceInfo with thei OSDeviceLTPK from the decrypted sub-TLV.
echo -n "$iOSDeviceInfo" | ./pairing/verify.sh "$pairingStorePath/$iOSDevicePairingID/iOSDeviceLTPK" "$iOSDeviceSignature" || {
    logger_error "Invalid iOSDeviceSignature"
    # If signature verification fails, the accessory must respond with the following TLV items:
    jq -n "{\"$TLV_STATE\": $TLV_M6, \"$TLV_ERROR\": $TLV_ERROR_AUTHENTICATION}" | ./util/tlv_encode.sh
    exit 4
}

# Derive AccessoryX from the SRP shared secret by using HKDF-SHA-512 with the following parameters:
AccessoryX="$(echo -n "$srpSharedSecret" | dash ./pairing/hkdf.sh "Pair-Setup-Accessory-Sign-Salt" "Pair-Setup-Accessory-Sign-Info")" || {
    logger_error 'HKDF failed'
    exit 1
}

AccessoryLTPK="$(cat "$storePath/AccessoryLTPK" | ./util/bin2hex.sh)"

# Concatenate AccessoryX with the accessory's PairingIdentifier, AccessoryPairingID, and its long-term public key, AccessoryLTPK
AccessoryInfo="${AccessoryX}$(echo -n "$AccessoryPairingID" | ./util/bin2hex.sh)${AccessoryLTPK}"

# Use Ed25519 to generate AccessorySignature by signing AccessoryInfo with its long-term secret key, AccessoryLTSK.
AccessorySignature="$(echo -n "$AccessoryInfo" | ./pairing/sign.sh "$storePath/AccessoryLTSK")" || {
    logger_error 'Signing failed'
    exit 1
}

# Construct the sub-TLV with the following TLV items:
subTLV="$(jq -n "{\"$TLV_IDENTIFIER\": \"$(echo -n "$AccessoryPairingID" | ./util/bin2hex.sh)\", \"$TLV_PUBLIC_KEY\": \"$AccessoryLTPK\", \"$TLV_SIGNATURE\": \"$AccessorySignature\"}" | ./util/tlv_encode.sh)"

# Encrypt the sub-TLV, encryptedData, and generate the 16 byte authtag, authTag. This uses the ChaCha20-Poly1305 AEAD algorithm
encrypted="$(echo -n "$subTLV" | ./pairing/encrypt_and_digest.sh "PS-Msg06" "$sessionKey")" || {
    logger_error "Encrypting M5 response failed"
    exit 1
}

response="{\"$TLV_STATE\": $TLV_M6, \"$TLV_ENCRYPTED_DATA\": \"$encrypted\"}"
jq -n "$response" | ./util/tlv_encode.sh

logger_debug "M6 response: $response"
