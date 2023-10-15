import tweetnacl from "tweetnacl";
import { writeToStore } from './common';

export function createSecrets(storePath: string): void {
    // Generate its Ed25519 long-term public key, AccessoryLTPK, and long-term secret key, AccessoryLTSK, if they donʼt exist.
    const keyPair = tweetnacl.sign.keyPair();
    writeToStore(storePath + "/AccessoryLTPK", Buffer.from(keyPair.publicKey));
    writeToStore(storePath + "/AccessoryLTSK", Buffer.from(keyPair.secretKey));
}