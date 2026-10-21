//! Provider passwords live in the OS credential store, never in SQLite.
//!
//! AbiPlayer kept M3U URLs with embedded passwords in plaintext; here the
//! catalog database holds no secret at all.

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Mutex;

use chacha20poly1305::aead::rand_core::RngCore;
use chacha20poly1305::aead::{Aead, KeyInit, OsRng, Payload};
use chacha20poly1305::{XChaCha20Poly1305, XNonce};

pub trait SecretStore: Send + Sync {
    fn get(&self, key: &str) -> Option<String>;
    fn set(&self, key: &str, value: &str) -> Result<(), String>;
    fn delete(&self, key: &str);
}

#[cfg(not(target_os = "android"))]
const SERVICE: &str = "Karadelik IPTV Player";

/// Windows Credential Manager / macOS and iOS Keychain.
#[cfg(not(target_os = "android"))]
pub struct OsKeyring;

#[cfg(not(target_os = "android"))]
impl SecretStore for OsKeyring {
    fn get(&self, key: &str) -> Option<String> {
        keyring::Entry::new(SERVICE, key).ok()?.get_password().ok()
    }

    fn set(&self, key: &str, value: &str) -> Result<(), String> {
        keyring::Entry::new(SERVICE, key)
            .and_then(|e| e.set_password(value))
            .map_err(|e| e.to_string())
    }

    fn delete(&self, key: &str) {
        if let Ok(e) = keyring::Entry::new(SERVICE, key) {
            let _ = e.delete_credential();
        }
    }
}

/// For tests and for platforms without a credential store.
#[derive(Default)]
pub struct MemorySecrets(Mutex<HashMap<String, String>>);

impl SecretStore for MemorySecrets {
    fn get(&self, key: &str) -> Option<String> {
        self.0.lock().unwrap().get(key).cloned()
    }

    fn set(&self, key: &str, value: &str) -> Result<(), String> {
        self.0.lock().unwrap().insert(key.to_string(), value.to_string());
        Ok(())
    }

    fn delete(&self, key: &str) {
        self.0.lock().unwrap().remove(key);
    }
}

/// Where the OS offers no credential store to native code (Android): one
/// file in the app's private folder, sealed with XChaCha20-Poly1305 under a
/// 32-byte key that the host keeps in the OS key store (Android Keystore).
/// Without that key the file is unreadable; the catalog still holds no secret.
pub struct SealedFileSecrets {
    path: PathBuf,
    cipher: XChaCha20Poly1305,
    entries: Mutex<HashMap<String, String>>,
}

const SEALED_MAGIC: &[u8; 4] = b"KPS1";

impl SealedFileSecrets {
    /// Opens (or starts) the file. A file that does not open under this key
    /// is an error, not an empty store: the user's passwords must not be
    /// silently replaced.
    pub fn open(path: PathBuf, key: &[u8]) -> Result<Self, String> {
        let key: [u8; 32] = key.try_into().map_err(|_| "the secrets key must be 32 bytes".to_string())?;
        let cipher = XChaCha20Poly1305::new(&key.into());
        let entries = match std::fs::read(&path) {
            Ok(data) => {
                if data.len() < 4 + 24 || &data[..4] != SEALED_MAGIC {
                    return Err("the secrets file is damaged".into());
                }
                let plain = cipher
                    .decrypt(XNonce::from_slice(&data[4..28]), Payload { msg: &data[28..], aad: SEALED_MAGIC })
                    .map_err(|_| "the secrets file does not open with this device's key".to_string())?;
                serde_json::from_slice(&plain).map_err(|e| e.to_string())?
            }
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => HashMap::new(),
            Err(e) => return Err(e.to_string()),
        };
        Ok(Self { path, cipher, entries: Mutex::new(entries) })
    }

    fn save(&self, entries: &HashMap<String, String>) -> Result<(), String> {
        let plain = serde_json::to_vec(entries).map_err(|e| e.to_string())?;
        let mut nonce = [0u8; 24];
        OsRng.fill_bytes(&mut nonce);
        let sealed = self
            .cipher
            .encrypt(XNonce::from_slice(&nonce), Payload { msg: &plain, aad: SEALED_MAGIC })
            .map_err(|_| "could not seal the secrets file".to_string())?;
        let mut out = Vec::with_capacity(4 + 24 + sealed.len());
        out.extend_from_slice(SEALED_MAGIC);
        out.extend_from_slice(&nonce);
        out.extend_from_slice(&sealed);
        // Replace, never truncate in place: a crash keeps the old file.
        let tmp = self.path.with_extension("tmp");
        std::fs::write(&tmp, &out).map_err(|e| e.to_string())?;
        std::fs::rename(&tmp, &self.path).map_err(|e| e.to_string())
    }
}

impl SecretStore for SealedFileSecrets {
    fn get(&self, key: &str) -> Option<String> {
        self.entries.lock().unwrap().get(key).cloned()
    }

    fn set(&self, key: &str, value: &str) -> Result<(), String> {
        let mut entries = self.entries.lock().unwrap();
        entries.insert(key.to_string(), value.to_string());
        self.save(&entries)
    }

    fn delete(&self, key: &str) {
        let mut entries = self.entries.lock().unwrap();
        if entries.remove(key).is_some() {
            let _ = self.save(&entries);
        }
    }
}

pub fn password_key(source_id: &str) -> String {
    format!("source:{source_id}:password")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sealed_file_round_trip_and_wrong_key() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("secrets.bin");
        let key = [7u8; 32];
        let store = SealedFileSecrets::open(path.clone(), &key).unwrap();
        store.set("source:1:password", "p@ss/ğü#?").unwrap();
        store.set("tmdb", "k").unwrap();
        store.delete("tmdb");
        drop(store);

        let raw = std::fs::read(&path).unwrap();
        assert!(!raw.windows(4).any(|w| w == b"p@ss"), "stored sealed, not in plain text");

        let again = SealedFileSecrets::open(path.clone(), &key).unwrap();
        assert_eq!(again.get("source:1:password").as_deref(), Some("p@ss/ğü#?"));
        assert_eq!(again.get("tmdb"), None);

        assert!(SealedFileSecrets::open(path.clone(), &[8u8; 32]).is_err(), "another key does not open it");
        assert!(SealedFileSecrets::open(path, &[7u8; 31]).is_err());
    }
}
