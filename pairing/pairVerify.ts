import { env } from "process";
import { spawnSync } from "child_process";
import * as tlv from "./tlv";
import { readSync } from 'fs';
import { TLVValues, PairingStates, log_debug, log_info, log_error, respondTLV, readFromStore, TLVErrorCode, extractMessageAndAuthTag, writeToStore } from './common';

export function pairVerify(AccessoryPairingID: string, storePath: string, sessionStorePath: string): void {
    const data = Buffer.alloc(parseInt(env.CONTENT_LENGTH!));
    readSync(0, data, 0, parseInt(env.CONTENT_LENGTH!), null);

    const tlvData = tlv.decode(data);
    const sequence = tlvData[TLVValues.STATE][0]; // value is single byte with sequence number

    log_debug("pairVerify with sequence: " + sequence + " and data length: " + data.length);

    if (sequence === PairingStates.M1) {
        pairVerifyM1(tlvData, Buffer.from(AccessoryPairingID), storePath, sessionStorePath);
    } else if (sequence === PairingStates.M3) {
        pairVerifyM3(tlvData, storePath, sessionStorePath);
    } else {
        log_error("Invalid state/sequence number");

        respondTLV(400, tlv.encode(TLVValues.STATE, sequence + 1,
                                   TLVValues.ERROR, TLVErrorCode.UNKNOWN));
    }
}

function pairVerifyM1(tlvData: Record<number, Buffer>, AccessoryPairingID: Buffer, storePath: string, sessionStorePath: string): void {
    log_debug("M2: Verify Start Response");

    // Generate new, random Curve25519 keypair.
    //const keyPair = tweetnacl.box.keyPair();
    //const AccessorySecretKeyOrig = Buffer.from(keyPair.secretKey);
    //const AccessoryPublicKeyOrig = Buffer.from(keyPair.publicKey);

    let keypair = spawnSync("./generate_encode_keypair.sh", [sessionStorePath + '/accessoryPublicKey', '-']);
    if (keypair.status != 0) {
        throw new Error("Keypair generation failed: " + keypair.stderr.toString());
    }
    const priv = keypair.stdout.toString().trim();

    const iOSDevicePublicKey = tlvData[TLVValues.PUBLIC_KEY];
    
    // Generate the shared secret, SharedSecret, from its Curve25519 secret key and the iOSdevice's Curve25519 public key.
    
    const AccessorySecretKey = Buffer.from(priv, 'hex');
    //const AccessorySecretKey = AccessorySecretKeyOrig;
    const AccessoryPublicKey = readFromStore(sessionStorePath + '/accessoryPublicKey');
    //const AccessoryPublicKey = AccessoryPublicKeyOrig;

    //log_debug("M2: Got secret key (" + priv.length + "): " + priv);
    //log_debug("M2: Got secret key orig: " + AccessorySecretKeyOrig.toString('hex'));
    //log_debug("M2: Got public key     : " + AccessoryPublicKey.toString('hex'));
    //log_debug("M2: Got public key orig: " + AccessoryPublicKeyOrig.toString('hex'));

    //const sharedSecret = Buffer.from(hapCrypto.generateCurve25519SharedSecKey(AccessorySecretKey, iOSDevicePublicKey));
    let ss = spawnSync("./generate_curve25519_shared_sec_key.sh", [AccessorySecretKey.toString('hex'), iOSDevicePublicKey.toString('hex')]);
    if (ss.status != 0) {
        throw new Error("Keypair generation failed: " + ss.stderr.toString());
    }
    const sharedSecret = Buffer.from(ss.stdout.toString().trim(), 'hex');
    log_debug("M2: Got sharedSecret: " + sharedSecret.toString('hex'));

    // Construct AccessoryInfo by concatenating the following items in order:
    const AccessoryInfo = Buffer.concat([AccessoryPublicKey, AccessoryPairingID, iOSDevicePublicKey]);

    // Use Ed25519 to generate AccessorySignature by signing AccessoryInfo with its long-term secret key, AccessoryLTSK.
    //const AccessorySignature = tweetnacl.sign.detached(AccessoryInfo, readFromStore(storePath + '/AccessoryLTSK'));
    let sign = spawnSync("./sign.sh", [storePath + '/AccessoryLTSK'], {input: AccessoryInfo});
    if (sign.status != 0) {
        throw new Error("Signing failed: " + sign.stderr.toString());
    }
    const AccessorySignature = Uint8Array.from(Buffer.from(sign.stdout.toString(), 'hex'));

    // Construct a sub-TLV with the following items:
    const subTLV = tlv.encode(TLVValues.IDENTIFIER, AccessoryPairingID,
                              TLVValues.SIGNATURE, AccessorySignature);

    // Derive the symmetric session encryption key, SessionKey, from the Curve25519 shared secret by using HKDF-SHA-512 
    //const SessionKey = hapCrypto.HKDF("sha512", Buffer.from("Pair-Verify-Encrypt-Salt"), sharedSecret, Buffer.from("Pair-Verify-Encrypt-Info"), 32).slice(0, 32);
    let hkdf = spawnSync("./hkdf.sh", ["Pair-Verify-Encrypt-Salt", "Pair-Verify-Encrypt-Info"], {input: sharedSecret.toString('hex')});
    if (hkdf.status != 0) {
        throw new Error("HKDF failed: " + hkdf.stderr.toString());
    }
    const SessionKey = Buffer.from(hkdf.stdout.toString(), 'hex');

    // Encrypt the sub-TLV, encryptedData, and generate the 16-byte auth tag, authTag. This uses the ChaCha20-Poly1305 AEAD algorithm
    //const {ciphertext, authTag} = hapCrypto.chacha20_poly1305_encryptAndSeal(SessionKey, Buffer.from("PV-Msg02"), null, subTLV);
    //const encrypted = Buffer.concat([ciphertext, authTag]);
    let encrypt = spawnSync("./encrypt_and_digest.sh", ["PV-Msg02", SessionKey.toString('hex')], {input: subTLV});
    if (encrypt.status != 0) {
        throw new Error("Encrypting M5 response failed: " + encrypt.stderr.toString());
    }
    let encrypted = Buffer.from(encrypt.stdout.toString(), 'hex');

    writeToStore(sessionStorePath + '/iOSDevicePublicKey', iOSDevicePublicKey);
    writeToStore(sessionStorePath + '/accessoryPublicKey', AccessoryPublicKey);
    writeToStore(sessionStorePath + '/sharedSecret',       sharedSecret);

    // Construct the response with the following TLV items:
    respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M2,
                               TLVValues.PUBLIC_KEY, AccessoryPublicKey,
                               TLVValues.ENCRYPTED_DATA, encrypted));
    
    log_debug("M2 responded")
}

function pairVerifyM3(tlvData: Record<number, Buffer>, storePath: string, sessionStorePath: string): void {
    log_debug("M4: Verify Finish Response");

    const {messageData, authTagData} = extractMessageAndAuthTag(tlvData[TLVValues.ENCRYPTED_DATA]);

    const iOSDevicePublicKey = readFromStore(sessionStorePath + '/iOSDevicePublicKey');
    const AccessoryPublicKey = readFromStore(sessionStorePath + '/accessoryPublicKey');
    const sharedSecret       = readFromStore(sessionStorePath + '/sharedSecret');

    // Derive the symmetric session encryption key, SessionKey, from the Curve25519 shared secret by using HKDF-SHA-512 
    //const SessionKey = hapCrypto.HKDF("sha512", Buffer.from("Pair-Verify-Encrypt-Salt"), sharedSecret, Buffer.from("Pair-Verify-Encrypt-Info"), 32).slice(0, 32);
    let hkdf = spawnSync("./hkdf.sh", ["Pair-Verify-Encrypt-Salt", "Pair-Verify-Encrypt-Info"], {input: sharedSecret.toString('hex')});
    if (hkdf.status != 0) {
        throw new Error("HKDF failed: " + hkdf.stderr.toString());
    }
    const SessionKey = Buffer.from(hkdf.stdout.toString(), 'hex');

    let subTLV;
    try {
        // Verify the iOSdevice's authTag, which is appended to the encryptedData and contained within the kTLVType_EncryptedData TLV item, against encryptedData.
        // Decrypt the sub-TLV in encryptedData.
        //subTLV = hapCrypto.chacha20_poly1305_decryptAndVerify(SessionKey, Buffer.from("PV-Msg03"), null, messageData, authTagData);
        let decrypt = spawnSync("./decrypt_and_verify.sh", ["PV-Msg03", SessionKey.toString('hex'), authTagData.toString('hex')], {input: messageData});
        if (decrypt.status != 0) {
            log_error("Error while decrypting and verifying M3 subTlv: " + decrypt.stderr.toString());
            // If verification/decryption fails, the accessory must respond with the following TLV items:
            respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M4,
                                       TLVValues.ERROR, TLVErrorCode.AUTHENTICATION));
            return;
        }
        subTLV = Buffer.from(decrypt.stdout.toString(), 'hex');
    } catch (error) {
        log_error("Error while decrypting and verifying M3 subTlv");
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
        readFromStore(storePath + '/pairings/' + iOSDevicePairingID + '/iOSDevicePairingID');
    } catch (err) {
        log_info("Client iOSDevicePairingID " + iOSDevicePairingID + " not found -> not paired");
        // If not found, the accessory must respond with the following TLV items:
        respondTLV(400, tlv.encode(TLVValues.STATE, PairingStates.M4,
                                   TLVValues.ERROR, TLVErrorCode.AUTHENTICATION));
        return;
    }
    const iOSDeviceLTPK = readFromStore(storePath + '/pairings/' + iOSDevicePairingID + '/iOSDeviceLTPK');
    const iOSDeviceInfo = Buffer.concat([iOSDevicePublicKey, iOSDevicePairingID, AccessoryPublicKey]);
    
    // Use Ed25519 to verify iOSDeviceSignature using iOSDeviceLTPK against iOSDeviceInfo contained in the decrypted sub-TLV
    let iOSDeviceSignatureFile = storePath + '/pairings/' + iOSDevicePairingID + '/temp-iOSDeviceSignature';
    writeToStore(iOSDeviceSignatureFile, iOSDeviceSignature);

    let verify = spawnSync("./verify.sh", [storePath + '/pairings/' + iOSDevicePairingID + '/iOSDeviceLTPK', iOSDeviceSignatureFile], {input: iOSDeviceInfo});
    if (verify.status != 0) {
        log_error("Invalid iOSDeviceSignature: " + verify.stderr.toString());
        // If decryption fails, the accessory must respond with the following TLV items:
        respondTLV(400, tlv.encode(TLVValues.STATE, PairingStates.M4,
                                   TLVValues.ERROR, TLVErrorCode.AUTHENTICATION));
        return;
    }
    
    //const AccessoryToControllerKey = hapCrypto.HKDF("sha512", Buffer.from("Control-Salt"), sharedSecret, Buffer.from("Control-Read-Encryption-Key"), 32);
    let hkdf1 = spawnSync("./hkdf.sh", ["Control-Salt", "Control-Read-Encryption-Key"], {input: sharedSecret.toString('hex')});
    if (hkdf1.status != 0) {
        throw new Error("HKDF failed: " + hkdf1.stderr.toString());
    }
    const AccessoryToControllerKey = Buffer.from(hkdf1.stdout.toString(), 'hex');
    writeToStore(sessionStorePath + '/AccessoryToControllerKey', AccessoryToControllerKey);

    //const ControllerToAccessoryKey = hapCrypto.HKDF("sha512", Buffer.from("Control-Salt"), sharedSecret, Buffer.from("Control-Write-Encryption-Key"), 32)
    let hkdf2 = spawnSync("./hkdf.sh", ["Control-Salt", "Control-Write-Encryption-Key"], {input: sharedSecret.toString('hex')});
    if (hkdf2.status != 0) {
        throw new Error("HKDF failed: " + hkdf2.stderr.toString());
    }
    const ControllerToAccessoryKey = Buffer.from(hkdf2.stdout.toString(), 'hex');
    writeToStore(sessionStorePath + '/ControllerToAccessoryKey', ControllerToAccessoryKey);

    // Send the response to the iOS device with the following TLV items:
    respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M4));

    log_info("Pair-verify done!")
}