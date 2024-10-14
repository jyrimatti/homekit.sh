#! /usr/bin/env nix-shell
//! ```cargo
//! [dependencies]
//! chacha20poly1305 = "0.10.1"
//! hex = "0.4.3"
//! generic-array = "0.14.7"
//! anyhow = "1.0"
//! ```
/*
#!nix-shell -I channel:nixos-23.11-small -i rust-script -p rustc rust-script cargo libiconv
*/
use std::env;
use std::io;
use generic_array::GenericArray;
use chacha20poly1305::{
    aead::{AeadInPlace, KeyInit},
    consts::{U12, U16, U32},
    ChaCha20Poly1305
};
fn main() -> Result<(), anyhow::Error> {
    let args: Vec<String> = env::args().collect();

    let nonce_in = &args[1].as_bytes();    // raw nonce string
    let mut nonce = [0; 12];
    nonce[12-nonce_in.len()..].copy_from_slice(&nonce_in);

    let key = &hex::decode(&args[2])?;     // key as hex
    let authtag = &hex::decode(&args[3])?; // authtag as hex

    let cipher = ChaCha20Poly1305::new(GenericArray::<u8,U32>::from_slice(key));
    
    let mut buffer = String::new();
    io::stdin().read_line(&mut buffer)?;

    let mut result: Vec<u8> = Vec::new();
    result.extend_from_slice(&hex::decode(buffer.trim_end())?);
    cipher.decrypt_in_place_detached(GenericArray::<u8,U12>::from_slice(&nonce), b"", &mut result, GenericArray::<u8,U16>::from_slice(authtag)).ok().unwrap();
    
    // print decoded text as hex
    print!("{}", hex::encode(result));
    Ok(())
}
