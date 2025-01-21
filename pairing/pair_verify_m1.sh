#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p dash jq xxd rust-script
. ./prelude
set -eu

logger_trace 'pairing/pair_verify_m1.sh'

AccessoryPairingID="$1"
sessionStorePath="$2"
iOSDevicePublicKey="$3"

. ./util/tlv.sh

logger_debug "M2: Verify Start Response"

# Generate new, random Curve25519 keypair.
AccessorySecretKey=$(./pairing/generate_encode_keypair.sh "$sessionStorePath/AccessoryPublicKey" '-') || {
    logger_error 'Keypair generation failed'
    exit 1
}

# Generate the shared secret, SharedSecret, from its Curve25519 secret key and the iOSdevice's Curve25519 public key.
AccessoryPublicKey="$(dash ./util/bin2hex.sh < "$sessionStorePath/AccessoryPublicKey")"
sharedSecret=$(./pairing/generate_curve25519_shared_sec_key.sh "$AccessorySecretKey" "$iOSDevicePublicKey") || {
    logger_error 'Shared secret generation failed'
    exit 1
}

# Construct AccessoryInfo by concatenating the following items in order:
AccessoryInfo="$AccessoryPublicKey$(echo -n "$AccessoryPairingID" | dash ./util/bin2hex.sh)$iOSDevicePublicKey"

# Use Ed25519 to generate AccessorySignature by signing AccessoryInfo with its long-term secret key, AccessoryLTSK.
AccessorySignature=$(echo -n "$AccessoryInfo" | dash ./pairing/sign.sh "$HOMEKIT_SH_STORE_DIR/AccessoryLTSK") || {
    logger_error 'Signing failed'
    exit 1
}

# Construct a sub-TLV with the following items:
subTLV="$(echo -n "{\"$TLV_IDENTIFIER\": \"$(echo -n "$AccessoryPairingID" | dash ./util/bin2hex.sh)\", \"$TLV_SIGNATURE\": \"$AccessorySignature\"}" | ./util/tlv_encode.sh)"

# Derive the symmetric session encryption key, SessionKey, from the Curve25519 shared secret by using HKDF-SHA-512 
SessionKey=$(echo -n "$sharedSecret" | dash ./pairing/hkdf.sh "Pair-Verify-Encrypt-Salt" "Pair-Verify-Encrypt-Info") || {
    logger_error 'HKDF failed'
    exit 1
}

# Encrypt the sub-TLV, encryptedData, and generate the 16-byte auth tag, authTag. This uses the ChaCha20-Poly1305 AEAD algorithm
encrypted=$(echo -n "$subTLV" | rust-script ./pairing/encrypt_and_digest.sh "PV-Msg02" "$SessionKey") || {
    logger_error 'Encrypting M2 response failed'
    exit 1
}

echo -n "$iOSDevicePublicKey" | dash ./util/hex2bin.sh > "$sessionStorePath/iOSDevicePublicKey"
echo -n "$AccessoryPublicKey" | dash ./util/hex2bin.sh > "$sessionStorePath/AccessoryPublicKey"
echo -n "$sharedSecret"       | dash ./util/hex2bin.sh > "$sessionStorePath/sharedSecret"

echo -n "{\"$TLV_STATE\": $TLV_M2, \"$TLV_PUBLIC_KEY\": \"$AccessoryPublicKey\", \"$TLV_ENCRYPTED_DATA\": \"$encrypted\"}" \
  | ./util/tlv_encode.sh
