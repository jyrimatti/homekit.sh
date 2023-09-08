import { env } from "process";
import crypto from "crypto";
import { SRP, SrpServer } from "fast-srp-hap";
import tweetnacl from "tweetnacl";
import * as hapCrypto from "./hapCrypto";
import * as tlv from "./tlv";
import { readSync } from 'fs';
import { TLVValues, PairingStates, log_debug, log_info, log_error, respondTLV, readFromStore, TLVErrorCode, extractMessageAndAuthTag, writeToStore, mkStorePath } from './common';

export function pairSetup(setupCode: string, AccessoryPairingID: string, sessionStorePath: string): void {
    const data = Buffer.alloc(parseInt(env.CONTENT_LENGTH!));
    readSync(0, data, 0, parseInt(env.CONTENT_LENGTH!), null);

    const tlvData = tlv.decode(data);
    const sequence = tlvData[TLVValues.STATE][0]; // value is single byte with sequence number
    log_debug("pairSetup with sequence: " + sequence + " and data length: " + data.length);

    try {
        if (sequence === PairingStates.M1) {
            pairSetupM1(setupCode, sessionStorePath);
        } else if (sequence === PairingStates.M3) {
            pairSetupM3(setupCode, tlvData, sessionStorePath);
        } else if (sequence === PairingStates.M5) {
            pairSetupM5(setupCode, tlvData, Buffer.from(AccessoryPairingID), sessionStorePath);
        } else {
            log_error("Invalid state/sequence number");

            respondTLV(400, tlv.encode(TLVValues.STATE, sequence + 1,
                                    TLVValues.ERROR, TLVErrorCode.UNKNOWN));
        }
    } catch (error) {
        log_error("WTF? " + error);
        process.exit(1);
    }
}


function pairSetupM1(setupCode: string, sessionStorePath: string): void {
    log_debug("M2: SRP Start Response");

    /*try {
        readFromStore('iOSDevicePairingID');
        log("Already paired, aborting");

        // if the accessory is already paired, it must respond with the following TLV items:
        respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M2,
                                   TLVValues.ERROR, TLVErrorCode.UNAVAILABLE));
        return;
    } catch (err) {
        // ok, can continue
    }*/

    // Generate 16 bytes of random salt
    const salt = crypto.randomBytes(16);
    writeToStore(sessionStorePath + "/salt", salt);

    SRP.genKey(32).then(serverPrivateKey => {
        writeToStore(sessionStorePath + "/serverPrivateKey", serverPrivateKey);
    
        const srpServer = new SrpServer(SRP.params.hap,
                                        salt,
                                        Buffer.from("Pair-Setup"),
                                        Buffer.from(setupCode),
                                        serverPrivateKey);

        // Generate an SRP public key
        const accessorySRPPublicKey = srpServer.computeB();

        // Respond to the iOS deviceʼs request with the following TLV items:
        respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M2,
                                   TLVValues.PUBLIC_KEY, accessorySRPPublicKey,
                                   TLVValues.SALT, salt));
    });
}

function pairSetupM3(setupCode: string, tlvData: Record<number, Buffer>, sessionStorePath: string): void {
    log_debug("M4: SRP Verify Response");

    const srpServer = new SrpServer(SRP.params.hap,
                                    readFromStore(sessionStorePath + '/salt'),
                                    Buffer.from("Pair-Setup"),
                                    Buffer.from(setupCode),
                                    readFromStore(sessionStorePath + '/serverPrivateKey'));

    const iOSDeviceSRPPublicKey = tlvData[TLVValues.PUBLIC_KEY];
    const iOSDeviceSRPProof     = tlvData[TLVValues.PROOF];

    // Use the iOS deviceʼs SRP public key to compute the SRP shared secret key
    srpServer.setA(iOSDeviceSRPPublicKey);

    writeToStore(sessionStorePath + "/iOSDeviceSRPPublicKey", iOSDeviceSRPPublicKey);

    try {
        // Verify the iOS device's SRP proof 
        srpServer.checkM1(iOSDeviceSRPProof);
    } catch (err) {
        log_error("Invalid iOSDeviceSRPProof");

        // If verification fails, the accessory must respond with the following TLV items
        respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M4,
                                   TLVValues.ERROR, TLVErrorCode.AUTHENTICATION));
        return;
    }

    // Generate the accessory-side SRP proof
    const accessorySideSRPProof = srpServer.computeM2();

    respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M4,
                               TLVValues.PROOF, accessorySideSRPProof));
                               
    log_debug("M4: Responded");
}

function pairSetupM5(setupCode: string, tlvData: Record<number, Buffer>, AccessoryPairingID: Buffer, sessionStorePath: string): void {
    log_debug("<M5> Verification");

    const srpServer = new SrpServer(SRP.params.hap,
                                    readFromStore(sessionStorePath + '/salt'),
                                    Buffer.from("Pair-Setup"),
                                    Buffer.from(setupCode),
                                    readFromStore(sessionStorePath + '/serverPrivateKey'));
    srpServer.setA(readFromStore(sessionStorePath + '/iOSDeviceSRPPublicKey'));

    const {messageData, authTagData} = extractMessageAndAuthTag(tlvData[TLVValues.ENCRYPTED_DATA]);

    const srpSharedSecret = srpServer.computeK();

    // Derive the symmetric session encryption key, SessionKey,from the SRP shared secret by using HKDF-SHA-512 with the following parameters:
    const sessionKey = hapCrypto.HKDF("sha512",
                                      Buffer.from("Pair-Setup-Encrypt-Salt"),
                                      srpSharedSecret,
                                      Buffer.from("Pair-Setup-Encrypt-Info"),
                                      32);

    let plaintext;
    try {
        // Verify the iOSdevice's auth Tag, which is appended to the encrypted Data and contained within the kTLVType_EncryptedData TLV item, from encryptedData.
        // Decrypt the sub-TLV in encryptedData.
        plaintext = hapCrypto.chacha20_poly1305_decryptAndVerify(sessionKey, Buffer.from("PS-Msg05"), null, messageData, authTagData);
    } catch (error) {
        log_error("Error while decrypting and verifying M5 subTlv");
        // If verification/decryption fails, the accessory must respond with the following TLV items:
        respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M4,
                                   TLVValues.ERROR, TLVErrorCode.AUTHENTICATION));
        return;
    }

    // Derive iOSDeviceX from the SRP shared secret by using HKDF-SHA-512
    const iOSDeviceX = hapCrypto.HKDF("sha512",
                                      Buffer.from("Pair-Setup-Controller-Sign-Salt"),
                                      srpSharedSecret,
                                      Buffer.from("Pair-Setup-Controller-Sign-Info"),
                                      32);
    
    // decode the client payload and pass it on to the next step
    const M5Packet = tlv.decode(plaintext);
    const iOSDevicePairingID = M5Packet[TLVValues.IDENTIFIER];
    const iOSDeviceLTPK      = M5Packet[TLVValues.PUBLIC_KEY];
    const iOSDeviceSignature = M5Packet[TLVValues.SIGNATURE];

    // Construct iOSDeviceInfo by concatenating iOSDeviceX with the iOSdevice's Pairing Identifier, iOSDevicePairingID, from the decrypted sub-TLV and the iOS deviceʼs long-term public key, iOSDeviceLTPK from the decrypted sub-TLV
    const iOSDeviceInfo = Buffer.concat([iOSDeviceX, iOSDevicePairingID, iOSDeviceLTPK]);

    // Use Ed25519 to verify the signature of the constructed iOSDeviceInfo with thei OSDeviceLTPK from the decrypted sub-TLV
    if (!tweetnacl.sign.detached.verify(iOSDeviceInfo, iOSDeviceSignature, iOSDeviceLTPK)) {
        log_error("Invalid iOSDeviceSignature");
        // If signature verification fails, the accessory must respond with the following TLV items:
        respondTLV(400, tlv.encode(TLVValues.STATE, PairingStates.M6,
                                   TLVValues.ERROR, TLVErrorCode.AUTHENTICATION));
        return;
    }

    // Persistently save the iOSDevicePairingID and iOSDeviceLTPK as a pairing.
    mkStorePath('pairings/' + iOSDevicePairingID);
    writeToStore('pairings/' + iOSDevicePairingID + '/iOSDevicePairingID',   iOSDevicePairingID);
    writeToStore('pairings/' + iOSDevicePairingID + '/iOSDeviceLTPK',        iOSDeviceLTPK);
    writeToStore('pairings/' + iOSDevicePairingID + '/iOSDevicePermissions', Buffer.from([1])); // Admin. TODO: implement proper permissions

    log_debug('<M6> Response Generation');

    // Derive AccessoryX from the SRP shared secret by using HKDF-SHA-512 with the following parameters:
    const AccessoryX = hapCrypto.HKDF("sha512",
                                      Buffer.from("Pair-Setup-Accessory-Sign-Salt"),
                                      srpSharedSecret,
                                      Buffer.from("Pair-Setup-Accessory-Sign-Info"),
                                      32);

    const AccessoryLTPK = readFromStore('AccessoryLTPK');
    const AccessoryLTSK = readFromStore('AccessoryLTSK');
    
    // Concatenate AccessoryX with the accessory's PairingIdentifier, AccessoryPairingID, and its long-term public key, AccessoryLTPK
    const AccessoryInfo = Buffer.concat([AccessoryX, AccessoryPairingID, AccessoryLTPK]);

    // Use Ed25519 to generate AccessorySignature by signing AccessoryInfo with its long-term secret key, AccessoryLTSK.
    const AccessorySignature = tweetnacl.sign.detached(AccessoryInfo, AccessoryLTSK);
    
    // Construct the sub-TLV with the following TLV items:
    const subTLV = tlv.encode(TLVValues.IDENTIFIER, AccessoryPairingID,
                              TLVValues.PUBLIC_KEY, AccessoryLTPK,
                              TLVValues.SIGNATURE, AccessorySignature);

    // Encrypt the sub-TLV, encryptedData, and generate the 16 byte authtag, authTag. This uses the ChaCha20-Poly1305 AEAD algorithm
    const {ciphertext,authTag} = hapCrypto.chacha20_poly1305_encryptAndSeal(sessionKey, Buffer.from("PS-Msg06"), null, subTLV);

    // Send the response to the iOS device with the following TLV items:
    respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M6,
                               TLVValues.ENCRYPTED_DATA, Buffer.concat([ciphertext, authTag])));

    log_info("Pair-setup done!")
    process.exit(42);
}
