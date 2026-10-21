//! The one place HTTP clients are made.
//!
//! Windows, macOS and iOS use the OS TLS stack (schannel / Security.framework)
//! and its trust store. Android has no OS TLS API for native code, so there
//! the clients use rustls (ring) with the Mozilla root store; the per-source
//! "accept invalid certificates" choice works the same on both.

use reqwest::blocking::ClientBuilder;

pub fn client() -> ClientBuilder {
    platform(reqwest::blocking::Client::builder())
}

#[cfg(not(target_os = "android"))]
fn platform(builder: ClientBuilder) -> ClientBuilder {
    builder
}

#[cfg(target_os = "android")]
fn platform(builder: ClientBuilder) -> ClientBuilder {
    use std::sync::OnceLock;
    static ROOTS: OnceLock<Vec<reqwest::Certificate>> = OnceLock::new();
    // Installing twice only fails when another provider won; either is fine.
    let _ = rustls::crypto::ring::default_provider().install_default();
    let roots = ROOTS.get_or_init(|| {
        webpki_root_certs::TLS_SERVER_ROOT_CERTS
            .iter()
            .filter_map(|der| reqwest::Certificate::from_der(der).ok())
            .collect()
    });
    builder.tls_certs_only(roots.iter().cloned())
}
