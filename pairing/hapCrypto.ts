// from: https://github.com/homebridge/HAP-NodeJS/tree/master/src/lib/util

import assert from "assert";
import crypto from "crypto";
import hkdf from "futoin-hkdf";
import tweetnacl from "tweetnacl";

if (!crypto.getCiphers().includes("chacha20-poly1305")) {
  assert.fail("The cipher 'chacha20-poly1305' is not supported with your current running nodejs version v" + process.version + ". " +
    "At least a nodejs version of v10.17.0 (excluding v11.0 and v11.1) is required!");
}

/**
 * @group Cryptography
 */
export function generateCurve25519SharedSecKey(priKey: Uint8Array, pubKey: Uint8Array): Uint8Array {
  return tweetnacl.scalarMult(priKey, pubKey);
}

/**
 * @group Cryptography
 */
export function HKDF(hashAlg: string, salt: Buffer, ikm: Buffer, info: Buffer, size: number): Buffer {
  return hkdf(ikm, size, { hash: hashAlg, salt: salt, info: info });
}

/**
 * @group Cryptography
 */
export function chacha20_poly1305_decryptAndVerify(key: Buffer, nonce: Buffer, aad: Buffer | null, ciphertext: Buffer, authTag: Buffer): Buffer {
  if (nonce.length < 12) { // openssl 3.x.x requires 98 bits nonce length
    nonce = Buffer.concat([
      Buffer.alloc(12 - nonce.length, 0),
      nonce,
    ]);
  }

  // // @ts-expect-error: types for this are really broken
  const decipher = crypto.createDecipheriv("chacha20-poly1305", key, nonce, { authTagLength: 16 });
  if (aad) {
    decipher.setAAD(aad, { plaintextLength: 9999 });
  }
  decipher.setAuthTag(authTag);
  const plaintext = decipher.update(ciphertext);
  decipher.final(); // final call verifies integrity using the auth tag. Throws error if something was manipulated!

  return plaintext;
}

/**
 * @group Cryptography
 */
export interface EncryptedData {
  ciphertext: Buffer;
  authTag: Buffer;
}

/**
 * @group Cryptography
 */
export function chacha20_poly1305_encryptAndSeal(key: Buffer, nonce: Buffer, aad: Buffer | null, plaintext: Buffer): EncryptedData {
  if (nonce.length < 12) { // openssl 3.x.x requires 98 bits nonce length
    nonce = Buffer.concat([
      Buffer.alloc(12 - nonce.length, 0),
      nonce,
    ]);
  }

  // // @ts-expect-error: types for this are really broken
  const cipher = crypto.createCipheriv("chacha20-poly1305", key, nonce, { authTagLength: 16 });

  if (aad) {
    cipher.setAAD(aad, { plaintextLength: 9999 });
  }

  const ciphertext = cipher.update(plaintext);
  cipher.final(); // final call creates the auth tag
  const authTag = cipher.getAuthTag();

  return { // return type is a bit weird, but we are going to change that on a later code cleanup
    ciphertext: ciphertext,
    authTag: authTag,
  };
}
