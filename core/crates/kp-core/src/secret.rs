//! Provider passwords live in the OS credential store, never in SQLite.
//!
//! AbiPlayer kept M3U URLs with embedded passwords in plaintext; here the
//! catalog database holds no secret at all.

use std::collections::HashMap;
use std::sync::Mutex;

pub trait SecretStore: Send + Sync {
    fn get(&self, key: &str) -> Option<String>;
    fn set(&self, key: &str, value: &str) -> Result<(), String>;
    fn delete(&self, key: &str);
}

const SERVICE: &str = "Karadelik IPTV Player";

/// Windows Credential Manager / macOS Keychain.
pub struct OsKeyring;

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

pub fn password_key(source_id: &str) -> String {
    format!("source:{source_id}:password")
}
