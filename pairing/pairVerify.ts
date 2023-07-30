import { env } from "process";
import tweetnacl from "tweetnacl";
import * as hapCrypto from "./hapCrypto";
import * as tlv from "./tlv";
import { readSync } from 'fs';
import { TLVValues, PairingStates, log, respondTLV, readFromStore, TLVErrorCode, extractMessageAndAuthTag, writeToStore } from './common';

export function pairVerify(AccessoryPairingID: string, sessionStorePath: string): void {
    const data = Buffer.alloc(parseInt(env.CONTENT_LENGTH!));
    readSync(0, data, 0, parseInt(env.CONTENT_LENGTH!), null);

    const tlvData = tlv.decode(data);
    const sequence = tlvData[TLVValues.STATE][0]; // value is single byte with sequence number

    log("pairVerify with sequence: " + sequence + " and data length: " + data.length);

    if (sequence === PairingStates.M1) {
        pairVerifyM1(tlvData, Buffer.from(AccessoryPairingID), sessionStorePath);
    } else if (sequence === PairingStates.M3) {
        pairVerifyM3(tlvData, sessionStorePath);
    } else {
        log("Invalid state/sequence number");

        respondTLV(400, tlv.encode(TLVValues.STATE, sequence + 1,
                                   TLVValues.ERROR, TLVErrorCode.UNKNOWN));
    }
}

function pairVerifyM1(tlvData: Record<number, Buffer>, AccessoryPairingID: Buffer, sessionStorePath: string): void {
    log("M2: Verify Start Response");

    // Generate new, random Curve25519 keypair.
    const keyPair = tweetnacl.box.keyPair();

    const iOSDevicePublicKey = tlvData[TLVValues.PUBLIC_KEY];
    
    // Generate the shared secret, SharedSecret, from its Curve25519 secret key and the iOSdevice's Curve25519 public key.
    const AccessorySecretKey = Buffer.from(keyPair.secretKey);
    const AccessoryPublicKey = Buffer.from(keyPair.publicKey);
    const sharedSecret = Buffer.from(hapCrypto.generateCurve25519SharedSecKey(AccessorySecretKey, iOSDevicePublicKey));

    // Construct AccessoryInfo by concatenating the following items in order:
    const AccessoryInfo = Buffer.concat([AccessoryPublicKey, AccessoryPairingID, iOSDevicePublicKey]);

    // Use Ed25519 to generate AccessorySignature by signing AccessoryInfo with its long-term secret key, AccessoryLTSK.
    const AccessorySignature = tweetnacl.sign.detached(AccessoryInfo, readFromStore('AccessoryLTSK'));

    // Construct a sub-TLV with the following items:
    const subTLV = tlv.encode(TLVValues.IDENTIFIER, AccessoryPairingID,
                              TLVValues.SIGNATURE, AccessorySignature);

    // Derive the symmetric session encryption key, SessionKey, from the Curve25519 shared secret by using HKDF-SHA-512 
    const SessionKey = hapCrypto.HKDF("sha512", Buffer.from("Pair-Verify-Encrypt-Salt"), sharedSecret, Buffer.from("Pair-Verify-Encrypt-Info"), 32).slice(0, 32);

    // Encrypt the sub-TLV, encryptedData, and generate the 16-byte auth tag, authTag. This uses the ChaCha20-Poly1305 AEAD algorithm
    const {ciphertext, authTag} = hapCrypto.chacha20_poly1305_encryptAndSeal(SessionKey, Buffer.from("PV-Msg02"), null, subTLV);

    writeToStore(sessionStorePath + '/iOSDevicePublicKey', iOSDevicePublicKey);
    writeToStore(sessionStorePath + '/accessoryPublicKey', AccessoryPublicKey);
    writeToStore(sessionStorePath + '/sharedSecret',       sharedSecret);

    // Construct the response with the following TLV items:
    respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M2,
                               TLVValues.PUBLIC_KEY, AccessoryPublicKey,
                               TLVValues.ENCRYPTED_DATA, Buffer.concat([ciphertext, authTag])));
    
    log("M2 responded")
}

function pairVerifyM3(tlvData: Record<number, Buffer>, sessionStorePath: string): void {
    log("M4: Verify Finish Response");

    const {messageData, authTagData} = extractMessageAndAuthTag(tlvData[TLVValues.ENCRYPTED_DATA]);

    const iOSDevicePublicKey = readFromStore(sessionStorePath + '/iOSDevicePublicKey');
    const AccessoryPublicKey = readFromStore(sessionStorePath + '/accessoryPublicKey');
    const sharedSecret       = readFromStore(sessionStorePath + '/sharedSecret');

    // Derive the symmetric session encryption key, SessionKey, from the Curve25519 shared secret by using HKDF-SHA-512 
    const SessionKey = hapCrypto.HKDF("sha512",
                                      Buffer.from("Pair-Verify-Encrypt-Salt"),
                                      sharedSecret,
                                      Buffer.from("Pair-Verify-Encrypt-Info"),
                                      32).slice(0, 32);

    let subTLV;
    try {
        // Verify the iOSdevice's authTag, which is appended to the encryptedData and contained within the kTLVType_EncryptedData TLV item, against encryptedData.
        // Decrypt the sub-TLV in encryptedData.
        subTLV = hapCrypto.chacha20_poly1305_decryptAndVerify(SessionKey, Buffer.from("PV-Msg03"), null, messageData, authTagData);
    } catch (error) {
        log("Failed to decrypt and/or verify");
        // If verification/decryption fails, the accessory must respond with the following TLV items:
        respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M4,
                                   TLVValues.ERROR, TLVErrorCode.AUTHENTICATION));
        return;
    }
    const decoded = tlv.decode(subTLV);

    const iOSDevicePairingID = decoded[TLVValues.IDENTIFIER];
    const iOSDeviceSignature = decoded[TLVValues.SIGNATURE];
    
    // Use the iOS deviceʼs Pairing Identifier, iOSDevicePairingID, to look up the iOS deviceʼs long-term public key, iOSDeviceLTPK, in its list of paired controllers.
    
    try {
        readFromStore('pairings/' + iOSDevicePairingID + '/iOSDevicePairingID');
    } catch (err) {
        log("Client iOSDevicePairingID " + iOSDevicePairingID + " not found -> not paired");
        // If not found, the accessory must respond with the following TLV items:
        respondTLV(400, tlv.encode(TLVValues.STATE, PairingStates.M4,
                                   TLVValues.ERROR, TLVErrorCode.AUTHENTICATION));
        return;
    }
    const iOSDeviceLTPK = readFromStore('pairings/' + iOSDevicePairingID + '/iOSDeviceLTPK');
    const iOSDeviceInfo = Buffer.concat([iOSDevicePublicKey, iOSDevicePairingID, AccessoryPublicKey]);
    
    // Use Ed25519 to verify iOSDeviceSignature using iOSDeviceLTPK against iOSDeviceInfo contained in the decrypted sub-TLV
    if (!tweetnacl.sign.detached.verify(iOSDeviceInfo, iOSDeviceSignature, iOSDeviceLTPK)) {
        log("Client provided an invalid signature");
        // If decryption fails, the accessory must respond with the following TLV items:
        respondTLV(400, tlv.encode(TLVValues.STATE, PairingStates.M4,
                                   TLVValues.ERROR, TLVErrorCode.AUTHENTICATION));
        return;
    }
    
    writeToStore(sessionStorePath + '/AccessoryToControllerKey', hapCrypto.HKDF("sha512", Buffer.from("Control-Salt"), sharedSecret, Buffer.from("Control-Read-Encryption-Key"), 32));
    writeToStore(sessionStorePath + '/ControllerToAccessoryKey', hapCrypto.HKDF("sha512", Buffer.from("Control-Salt"), sharedSecret, Buffer.from("Control-Write-Encryption-Key"), 32));

    // Send the response to the iOS device with the following TLV items:
    respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M4));

    log("Pair-verify done!")
}