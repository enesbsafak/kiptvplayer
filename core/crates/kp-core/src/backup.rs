//! Encrypted backup files: everything the user made (sources with their
//! passwords, favourites, history, edits, groups, guide corrections,
//! reminders, settings), never the catalogs, which a sync brings back.
//!
//! Layout: "KPBK", format version, Argon2id costs (m KiB, t, p), 16-byte
//! salt, 24-byte nonce, then XChaCha20-Poly1305 over the gzip'd JSON with
//! the header as associated data, so neither costs nor salt can be
//! swapped. A wrong password and a damaged file both fail authentication.

use std::io::{Read, Write};

use argon2::{Algorithm, Argon2, Params, Version};
use chacha20poly1305::aead::rand_core::RngCore;
use chacha20poly1305::aead::{Aead, KeyInit, OsRng, Payload};
use chacha20poly1305::{XChaCha20Poly1305, XNonce};

const MAGIC: &[u8; 4] = b"KPBK";
const FORMAT: u8 = 1;
const HEADER: usize = 4 + 1 + 12 + 16 + 24;

/// 64 MiB, 3 passes: about half a second on a laptop, per guess.
const M_COST: u32 = 64 * 1024;
const T_COST: u32 = 3;
const P_COST: u32 = 1;

#[derive(Debug, thiserror::Error, PartialEq)]
pub enum BackupError {
    #[error("not a Karadelik backup")]
    NotABackup,
    #[error("made by a newer version")]
    TooNew,
    #[error("wrong password or damaged file")]
    Rejected,
    #[error("{0}")]
    Other(String),
}

fn key(password: &str, salt: &[u8], m: u32, t: u32, p: u32) -> Result<[u8; 32], BackupError> {
    let params = Params::new(m, t, p, Some(32)).map_err(|e| BackupError::Other(e.to_string()))?;
    let mut out = [0u8; 32];
    Argon2::new(Algorithm::Argon2id, Version::V0x13, params)
        .hash_password_into(password.as_bytes(), salt, &mut out)
        .map_err(|e| BackupError::Other(e.to_string()))?;
    Ok(out)
}

/// Compresses and encrypts [plain] under [password].
pub fn seal(plain: &[u8], password: &str) -> Result<Vec<u8>, BackupError> {
    // Unit tests run unoptimized, where the real costs take minutes; the
    // costs travel in the header, so opening works either way.
    if cfg!(test) {
        return seal_with(plain, password, 64, 1, 1);
    }
    seal_with(plain, password, M_COST, T_COST, P_COST)
}

fn seal_with(plain: &[u8], password: &str, m: u32, t: u32, p: u32) -> Result<Vec<u8>, BackupError> {
    let mut gz = flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::default());
    gz.write_all(plain).map_err(|e| BackupError::Other(e.to_string()))?;
    let packed = gz.finish().map_err(|e| BackupError::Other(e.to_string()))?;

    let mut salt = [0u8; 16];
    let mut nonce = [0u8; 24];
    OsRng.fill_bytes(&mut salt);
    OsRng.fill_bytes(&mut nonce);
    let mut out = Vec::with_capacity(HEADER + packed.len() + 16);
    out.extend_from_slice(MAGIC);
    out.push(FORMAT);
    for v in [m, t, p] {
        out.extend_from_slice(&v.to_le_bytes());
    }
    out.extend_from_slice(&salt);
    out.extend_from_slice(&nonce);
    let cipher = XChaCha20Poly1305::new(&key(password, &salt, m, t, p)?.into());
    let sealed = cipher
        .encrypt(XNonce::from_slice(&nonce), Payload { msg: &packed, aad: &out[..HEADER] })
        .map_err(|_| BackupError::Other("encryption failed".into()))?;
    out.extend_from_slice(&sealed);
    Ok(out)
}

/// Decrypts and decompresses a [seal]ed file.
pub fn open(data: &[u8], password: &str) -> Result<Vec<u8>, BackupError> {
    if data.len() < HEADER + 16 || &data[..4] != MAGIC {
        return Err(BackupError::NotABackup);
    }
    if data[4] > FORMAT {
        return Err(BackupError::TooNew);
    }
    let num = |at: usize| u32::from_le_bytes(data[at..at + 4].try_into().unwrap_or_default());
    let (m, t, p) = (num(5), num(9), num(13));
    // A hostile header must not make us allocate gigabytes.
    if m > 1024 * 1024 || t > 64 || p > 16 {
        return Err(BackupError::NotABackup);
    }
    let salt = &data[17..33];
    let nonce = &data[33..57];
    let cipher = XChaCha20Poly1305::new(&key(password, salt, m, t, p)?.into());
    let packed = cipher
        .decrypt(XNonce::from_slice(nonce), Payload { msg: &data[HEADER..], aad: &data[..HEADER] })
        .map_err(|_| BackupError::Rejected)?;
    let mut plain = Vec::new();
    flate2::read::GzDecoder::new(packed.as_slice())
        .read_to_end(&mut plain)
        .map_err(|_| BackupError::Rejected)?;
    Ok(plain)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip_and_refusals() {
        // Cheap costs: the format, not the KDF, is under test.
        let sealed = seal_with(b"{\"merhaba\": 1}", "doğru parola", 64, 1, 1).unwrap();
        assert_eq!(open(&sealed, "doğru parola").unwrap(), b"{\"merhaba\": 1}");
        assert_eq!(open(&sealed, "yanlış").unwrap_err(), BackupError::Rejected);

        let mut tampered = sealed.clone();
        *tampered.last_mut().unwrap() ^= 1;
        assert_eq!(open(&tampered, "doğru parola").unwrap_err(), BackupError::Rejected);
        let mut costs = sealed.clone();
        costs[9] = 2; // t_cost changed: the header is authenticated
        assert_eq!(open(&costs, "doğru parola").unwrap_err(), BackupError::Rejected);

        assert_eq!(open(b"PK\x03\x04 a zip", "x").unwrap_err(), BackupError::NotABackup);
        let mut newer = sealed;
        newer[4] = 9;
        assert_eq!(open(&newer, "doğru parola").unwrap_err(), BackupError::TooNew);
    }
}
