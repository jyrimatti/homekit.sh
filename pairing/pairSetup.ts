import { env } from "process";
import { spawnSync } from "child_process";
//import crypto from "crypto";
//import BigInteger from "./jsbn";
//import tweetnacl from "tweetnacl";
import { SRP, SrpServer, SrpParams } from "fast-srp-hap";
//import * as hapCrypto from "./hapCrypto";
import * as tlv from "./tlv";
import { readSync } from 'fs';
import { TLVValues, PairingStates, log_debug, log_info, log_error, respondTLV, readFromStore, TLVErrorCode, extractMessageAndAuthTag, writeToStore, mkStorePath } from './common';

export function pairSetup(setupCode: string, AccessoryPairingID: string, storePath: string): void {
    const data = Buffer.alloc(parseInt(env.CONTENT_LENGTH!));
    readSync(0, data, 0, parseInt(env.CONTENT_LENGTH!), null);

    const tlvData = tlv.decode(data);
    const sequence = tlvData[TLVValues.STATE][0]; // value is single byte with sequence number
    log_debug("pairSetup with sequence: " + sequence + " and data length: " + data.length);

    try {
        if (sequence === PairingStates.M1) {
            pairSetupM1(setupCode, storePath);
        } else if (sequence === PairingStates.M3) {
            pairSetupM3(setupCode, tlvData, storePath);
        } else if (sequence === PairingStates.M5) {
            pairSetupM5(setupCode, tlvData, Buffer.from(AccessoryPairingID), storePath);
        } else {
            log_error("Invalid state/sequence number");

            respondTLV(400, tlv.encode(TLVValues.STATE, sequence + 1,
                                       TLVValues.ERROR, TLVErrorCode.UNKNOWN));
        }
    } catch (error) {
        log_error("WTF? " + error + error.stack);
        process.exit(1);
    }
}


function padTo(n: Buffer, len: number): Buffer {
    const padding = len - n.length;
    const result = Buffer.alloc(len);
    result.fill(0, 0, padding);
    n.copy(result, padding);
    return result;
  }
  
  function padToN(numberHex: String, params: SrpParams): Buffer {
    const n = numberHex.length % 2 !== 0 ? "0" + numberHex : numberHex;
    return padTo(Buffer.from(n, "hex"), params.N_length_bits / 8);
  }

function pairSetupM1(setupCode: string, storePath: string): void {
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
    //const salt = crypto.randomBytes(16);
    /*let gensalt = spawnSync("./pairing/generate_random_bytes.sh", ["16"], {cwd: '..'});
    if (gensalt.status != 0) {
        throw new Error("Salt generation failed: " + gensalt.stderr.toString());
    }
    const salt = Buffer.from(gensalt.stdout.toString(), 'hex');*/

    let genkey = spawnSync("./pairing/generate_random_bytes.sh", ["32"], {cwd: '..'});
    if (genkey.status != 0) {
        throw new Error("Server key generation failed: " + genkey.stderr.toString());
    }
    const serverPrivateKey = Buffer.from(genkey.stdout.toString(), 'hex');
    //SRP.genKey(32).then(serverPrivateKey => {
    writeToStore(storePath + "/serverPrivateKey", serverPrivateKey);
    log_debug("M2: server private key generated: " + serverPrivateKey.toString('hex'));

    let srp = spawnSync("./pairing/srp_get_serverkey.sh", ["Pair-Setup", setupCode, serverPrivateKey.toString('hex')], {cwd: '..'});
    if (srp.status != 0) {
        throw new Error("Server key generation failed: " + srp.stderr.toString());
    }
    const ret = srp.stdout.toString().split(',');
    const salt = Buffer.from(ret[0], 'hex');
    const accessorySRPPublicKey = Buffer.from(ret[1], 'hex');
    const verifier = Buffer.from(ret[2], 'hex');
    
    writeToStore(storePath + "/salt", salt);
    writeToStore(storePath + "/verifier", verifier);

    /*const srpServer = new SrpServer(SRP.params.hap,
                                    salt,
                                    Buffer.from("Pair-Setup"),
                                    Buffer.from(setupCode),
                                    serverPrivateKey);*/
    // Generate an SRP public key
    //const accessorySRPPublicKeyOrig = srpServer.computeB();
    //const k_orig = crypto.createHash(SRP.params.hap.hash).update(padToN(SRP.params.hap.N.toString(16), SRP.params.hap)).update(padToN(SRP.params.hap.g.toString(16), SRP.params.hap)).digest();
    //const v_orig = SRP.computeVerifier(SRP.params.hap, salt, Buffer.from("Pair-Setup"), Buffer.from(setupCode));
    //log_debug("M2: k               " + ret[3]);
    //log_debug("M2: k (orig):       " + k_orig.toString('hex'));
    //log_debug("M2: salt  computed: " + salt.toString('hex'));
    //log_debug("M2: verifier       : " + verifier.toString('hex'));
    //log_debug("M2: verifier (orig): " + v_orig.toString('hex'));
    //log_debug("M2: B        computed: " + accessorySRPPublicKey.toString('hex'));
    //log_debug("M2: B (orig) computed: " + accessorySRPPublicKeyOrig.toString('hex'));
    //log_debug("M2: B (orig):          " + new BigInteger(k_orig).multiply(new BigInteger(v_orig)).add(SRP.params.hap.g.modPow(new BigInteger(serverPrivateKey), SRP.params.hap.N)).mod(SRP.params.hap.N).toBuffer(SRP.params.hap.N_length_bits / 8).toString('hex'));

    // Respond to the iOS deviceʼs request with the following TLV items:
    respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M2,
                               TLVValues.PUBLIC_KEY, accessorySRPPublicKey,
                               TLVValues.SALT, salt));
    //});

    log_debug("M2: Responded");
}

/*class MyServer extends SrpServer {
    constructor(params: SrpParams, salt_buf: Buffer, identity_buf: Buffer, password_buf: Buffer, secret2_buf: Buffer) {
        super(params, salt_buf, identity_buf, password_buf, secret2_buf);
    }
    setA(A: Buffer): void {
        super.setA(A);
        log_debug("M4: u: " + this._u?.toString(16));
        log_debug("M4: S: " + this._S?.toString('hex'));
        log_debug("M4: K: " + this._K?.toString('hex'));
        log_debug("M4: M: " + this._M1?.toString('hex'));
    }
}*/

function pairSetupM3(setupCode: string, tlvData: Record<number, Buffer>, storePath: string): void {
    log_debug("M4: SRP Verify Response");

    const serverPrivateKey = readFromStore(storePath + '/serverPrivateKey');

    /*const srpServer = new SrpServer(SRP.params.hap,
                                    readFromStore(storePath + '/salt'),
                                    Buffer.from("Pair-Setup"),
                                    Buffer.from(setupCode),
                                    serverPrivateKey);*/

    const iOSDeviceSRPPublicKey = tlvData[TLVValues.PUBLIC_KEY];
    const iOSDeviceSRPProof     = tlvData[TLVValues.PROOF];

    // Use the iOS deviceʼs SRP public key to compute the SRP shared secret key
    //srpServer.setA(iOSDeviceSRPPublicKey);

    writeToStore(storePath + "/iOSDeviceSRPPublicKey", iOSDeviceSRPPublicKey);

    const verifier = readFromStore(storePath + "/verifier");
    const salt = readFromStore(storePath + "/salt");

    //const hN = crypto.createHash(SRP.params.hap.hash).update(SRP.params.hap.N.toBuffer(true)).digest();
    //const hN2 = crypto.createHash(SRP.params.hap.hash).update(SRP.params.hap.N.toBuffer()).digest();
    //const hG = crypto.createHash(SRP.params.hap.hash).update(SRP.params.hap.g.toBuffer(true)).digest();
    //const hG2 = crypto.createHash(SRP.params.hap.hash).update(SRP.params.hap.g.toBuffer()).digest();

    /*log_debug("M4: M1: " + iOSDeviceSRPProof.toString('hex'));
    log_debug("M4: hG: " + hG.toString('hex'));
    log_debug("M4: hG2: " + hG2.toString('hex'));
    log_debug("M4: hN1: " + hN.toString('hex'));
    log_debug("M4: hN2: " + hN2.toString('hex'));
    for (let i = 0; i < hN.length; i++) {
        hN[i] ^= hG[i];
    }
    log_debug("M4: hN: " + hN.toString('hex'));*/

    let verify = spawnSync("./pairing/srp_verify.sh", ["Pair-Setup",
                                                      verifier.toString('hex'),
                                                      salt.toString('hex'),
                                                      serverPrivateKey.toString('hex'),
                                                      iOSDeviceSRPPublicKey.toString('hex'),
                                                      iOSDeviceSRPProof.toString('hex')], {cwd: '..'});
    if (verify.status != 0) {
        log_error("Invalid iOSDeviceSRPProof");
        // If verification fails, the accessory must respond with the following TLV items
        respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M4,
                                   TLVValues.ERROR, TLVErrorCode.AUTHENTICATION));
        return;
    }
    const accessorySideSRPProof = Buffer.from(verify.stdout.toString(), 'hex');

    /*try {
        // Verify the iOS device's SRP proof 
        srpServer.checkM1(iOSDeviceSRPProof);
    } catch (err) {
        log_error("Invalid iOSDeviceSRPProof");

        // If verification fails, the accessory must respond with the following TLV items
        respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M4,
                                   TLVValues.ERROR, TLVErrorCode.AUTHENTICATION));
        return;
    }*/

    // Generate the accessory-side SRP proof
    //const accessorySideSRPProofOrig = srpServer.computeM2();

    log_debug("M4: got M2       : " + accessorySideSRPProof.toString('hex'));
    //log_debug("M4: got M2 (orig): " + accessorySideSRPProofOrig.toString('hex'));

    respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M4,
                               TLVValues.PROOF, accessorySideSRPProof));
                               
    log_debug("M4: Responded");
}

function pairSetupM5(setupCode: string, tlvData: Record<number, Buffer>, AccessoryPairingID: Buffer, storePath: string): void {
    log_debug("<M5> Verification");

    const srpServer = new SrpServer(SRP.params.hap,
                                    readFromStore(storePath + '/salt'),
                                    Buffer.from("Pair-Setup"),
                                    Buffer.from(setupCode),
                                    readFromStore(storePath + '/serverPrivateKey'));
    srpServer.setA(readFromStore(storePath + '/iOSDeviceSRPPublicKey'));

    const {messageData, authTagData} = extractMessageAndAuthTag(tlvData[TLVValues.ENCRYPTED_DATA]);

    const srpSharedSecret = srpServer.computeK();

    // Derive the symmetric session encryption key, SessionKey,from the SRP shared secret by using HKDF-SHA-512 with the following parameters:
    //const sessionKey = hapCrypto.HKDF("sha512", Buffer.from("Pair-Setup-Encrypt-Salt"), srpSharedSecret, Buffer.from("Pair-Setup-Encrypt-Info"), 32);
    let hkdf = spawnSync("./pairing/hkdf.sh", ["Pair-Setup-Encrypt-Salt", "Pair-Setup-Encrypt-Info"], {input: srpSharedSecret.toString('hex'), cwd: '..'});
    if (hkdf.status != 0) {
        throw new Error("HKDF failed: " + hkdf.stderr.toString());
    }
    const sessionKey = Buffer.from(hkdf.stdout.toString(), 'hex');

    let plaintext;
    try {
        // Verify the iOSdevice's auth Tag, which is appended to the encrypted Data and contained within the kTLVType_EncryptedData TLV item, from encryptedData.
        // Decrypt the sub-TLV in encryptedData.
        //plaintext = hapCrypto.chacha20_poly1305_decryptAndVerify(sessionKey, Buffer.from("PS-Msg05"), null, messageData, authTagData);
        let decrypt = spawnSync("./pairing/decrypt_and_verify.sh", ["PS-Msg05", sessionKey.toString('hex'), authTagData.toString('hex')], {input: messageData.toString('hex'), cwd: '..'});
        if (decrypt.status != 0) {
            log_error("Error while decrypting and verifying M5 subTlv: " + decrypt.stderr.toString());
            // If verification/decryption fails, the accessory must respond with the following TLV items:
            respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M4,
                                       TLVValues.ERROR, TLVErrorCode.AUTHENTICATION));
            return;
        }
        plaintext = Buffer.from(decrypt.stdout.toString(), 'hex');
    } catch (error) {
        log_error("Error while decrypting and verifying M5 subTlv");
        // If verification/decryption fails, the accessory must respond with the following TLV items:
        respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M4,
                                   TLVValues.ERROR, TLVErrorCode.AUTHENTICATION));
        return;
    }

    // Derive iOSDeviceX from the SRP shared secret by using HKDF-SHA-512
    //const iOSDeviceX = hapCrypto.HKDF("sha512", Buffer.from("Pair-Setup-Controller-Sign-Salt"), srpSharedSecret, Buffer.from("Pair-Setup-Controller-Sign-Info"), 32);
    let hkdf2 = spawnSync("./pairing/hkdf.sh", ["Pair-Setup-Controller-Sign-Salt", "Pair-Setup-Controller-Sign-Info"], {input: srpSharedSecret.toString('hex'), cwd: '..'});
    if (hkdf2.status != 0) {
        throw new Error("HKDF failed: " + hkdf2.stderr.toString());
    }
    const iOSDeviceX = Buffer.from(hkdf2.stdout.toString(), 'hex');
    
    // decode the client payload and pass it on to the next step
    const M5Packet = tlv.decode(plaintext);
    const iOSDevicePairingID = M5Packet[TLVValues.IDENTIFIER];
    const iOSDeviceLTPK      = M5Packet[TLVValues.PUBLIC_KEY];
    const iOSDeviceSignature = M5Packet[TLVValues.SIGNATURE];

    // Construct iOSDeviceInfo by concatenating iOSDeviceX with the iOSdevice's Pairing Identifier, iOSDevicePairingID, from the decrypted sub-TLV and the iOS deviceʼs long-term public key, iOSDeviceLTPK from the decrypted sub-TLV
    const iOSDeviceInfo = Buffer.concat([iOSDeviceX, iOSDevicePairingID, iOSDeviceLTPK]);

    mkStorePath(storePath + '/pairings/' + iOSDevicePairingID);

    // Persistently save the iOSDevicePairingID and iOSDeviceLTPK as a pairing.
    writeToStore(storePath + '/pairings/' + iOSDevicePairingID + '/iOSDevicePairingID',   iOSDevicePairingID);
    writeToStore(storePath + '/pairings/' + iOSDevicePairingID + '/iOSDeviceLTPK',        iOSDeviceLTPK);
    writeToStore(storePath + '/pairings/' + iOSDevicePairingID + '/iOSDevicePermissions', Buffer.from([1])); // Admin. TODO: implement proper permissions

    // Use Ed25519 to verify the signature of the constructed iOSDeviceInfo with thei OSDeviceLTPK from the decrypted sub-TLV.
    /*if (!tweetnacl.sign.detached.verify(iOSDeviceInfo, iOSDeviceSignature, iOSDeviceLTPK)) {
        log_error("Invalid iOSDeviceSignature");
    }*/
    let verify = spawnSync("./pairing/verify.sh", [storePath + '/pairings/' + iOSDevicePairingID + '/iOSDeviceLTPK', iOSDeviceSignature.toString('hex')], {input: iOSDeviceInfo.toString('hex'), cwd: '..'});
    if (verify.status != 0) {
        log_error("Invalid iOSDeviceSignature: " + verify.stderr.toString());
        // If signature verification fails, the accessory must respond with the following TLV items:
        respondTLV(400, tlv.encode(TLVValues.STATE, PairingStates.M6,
                                   TLVValues.ERROR, TLVErrorCode.AUTHENTICATION));
        return;
    }

    log_debug('<M6> Response Generation');

    // Derive AccessoryX from the SRP shared secret by using HKDF-SHA-512 with the following parameters:
    //const AccessoryX = hapCrypto.HKDF("sha512", Buffer.from("Pair-Setup-Accessory-Sign-Salt"), srpSharedSecret, Buffer.from("Pair-Setup-Accessory-Sign-Info"), 32);
    let hkdf3 = spawnSync("./pairing/hkdf.sh", ["Pair-Setup-Accessory-Sign-Salt", "Pair-Setup-Accessory-Sign-Info"], {input: srpSharedSecret.toString('hex'), cwd: '..'});
    if (hkdf3.status != 0) {
        throw new Error("HKDF failed: " + hkdf3.stderr.toString());
    }
    const AccessoryX = Buffer.from(hkdf3.stdout.toString(), 'hex');

    const AccessoryLTPK = readFromStore(storePath + '/AccessoryLTPK');
    
    // Concatenate AccessoryX with the accessory's PairingIdentifier, AccessoryPairingID, and its long-term public key, AccessoryLTPK
    const AccessoryInfo = Buffer.concat([AccessoryX, AccessoryPairingID, AccessoryLTPK]);

    // Use Ed25519 to generate AccessorySignature by signing AccessoryInfo with its long-term secret key, AccessoryLTSK.
    //const AccessorySignature = tweetnacl.sign.detached(AccessoryInfo, readFromStore(storePath + '/AccessoryLTSK'));
    let sign = spawnSync("./pairing/sign.sh", [storePath + '/AccessoryLTSK'], {input: AccessoryInfo.toString('hex'), cwd: '..'});
    if (sign.status != 0) {
        throw new Error("Signing failed: " + sign.stderr.toString());
    }
    let output = sign.stdout.toString();
    const AccessorySignature = Uint8Array.from(Buffer.from(output, 'hex'));
    
    // Construct the sub-TLV with the following TLV items:
    const subTLV = tlv.encode(TLVValues.IDENTIFIER, AccessoryPairingID,
                              TLVValues.PUBLIC_KEY, AccessoryLTPK,
                              TLVValues.SIGNATURE, AccessorySignature);

    // Encrypt the sub-TLV, encryptedData, and generate the 16 byte authtag, authTag. This uses the ChaCha20-Poly1305 AEAD algorithm
    //const {ciphertext,authTag} = hapCrypto.chacha20_poly1305_encryptAndSeal(sessionKey, Buffer.from("PS-Msg06"), null, subTLV);
    //const encrypted = Buffer.concat([ciphertext, authTag]);
    let encrypt = spawnSync("./pairing/encrypt_and_digest.sh", ["PS-Msg06", sessionKey.toString('hex')], {input: subTLV.toString('hex'), cwd: '..'});
    if (encrypt.status != 0) {
        throw new Error("Encrypting M5 response failed: " + encrypt.stderr.toString());
    }
    let encrypted = Buffer.from(encrypt.stdout.toString(), 'hex');

    // Send the response to the iOS device with the following TLV items:
    respondTLV(200, tlv.encode(TLVValues.STATE, PairingStates.M6,
                               TLVValues.ENCRYPTED_DATA, encrypted));

    log_info("Pair-setup done!")
    process.exit(42);
}
