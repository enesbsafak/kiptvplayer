//! Self-update: a small JSON feed names the newest installer and its
//! SHA-256; the installer is downloaded beside the library, verified, and run
//! silently once the app has quit. Earlier installers are kept, so the
//! previous version can be put back.
//!
//! Feed (`latest.json`, published with each release):
//! `{"version": "0.2.0", "url": "https://…/Setup-0.2.0.exe", "sha256": "…",
//!   "notes": {"tr": "…", "en": "…"}, "published": "2026-10-21"}`

use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::time::Duration;

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::lang::t;

#[derive(Debug, thiserror::Error)]
pub enum UpdateError {
    #[error("{}: {}", t("güncelleme sunucusuna ulaşılamadı", "could not reach the update server"), .0)]
    Network(String),
    #[error("{}", t("güncelleme bilgisi okunamadı", "could not read the update information"))]
    BadFeed,
    #[error("{}", t("indirilen dosya doğrulanamadı (SHA-256 farklı); kurulmadı", "the download failed verification (SHA-256 mismatch); not installed"))]
    Checksum,
    #[error("{}: {}", t("güncelleme kaydedilemedi", "could not save the update"), .0)]
    Io(#[from] std::io::Error),
}

pub type Result<T> = std::result::Result<T, UpdateError>;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Release {
    pub version: String,
    pub url: String,
    pub sha256: String,
    #[serde(default)]
    pub notes: std::collections::HashMap<String, String>,
    #[serde(default)]
    pub published: Option<String>,
}

impl Release {
    /// Release notes in the UI language, else whatever is there.
    pub fn notes_for(&self, language: &str) -> String {
        self.notes.get(language).or_else(|| self.notes.values().next()).cloned().unwrap_or_default()
    }
}

/// "1.10.0" > "1.9.3"; a pre-release suffix ("-beta.2") sorts below the
/// plain version.
pub fn is_newer(candidate: &str, current: &str) -> bool {
    fn parse(v: &str) -> (Vec<u64>, bool) {
        let v = v.trim().trim_start_matches('v');
        let (core, pre) = v.split_once(['-', '+']).map(|(c, p)| (c, !p.is_empty())).unwrap_or((v, false));
        (core.split('.').map(|p| p.parse().unwrap_or(0)).collect(), pre)
    }
    let (a, a_pre) = parse(candidate);
    let (b, b_pre) = parse(current);
    let n = a.len().max(b.len());
    for i in 0..n {
        let (x, y) = (a.get(i).copied().unwrap_or(0), b.get(i).copied().unwrap_or(0));
        if x != y {
            return x > y;
        }
    }
    // Same numbers: the final release beats its pre-release.
    !a_pre && b_pre
}

fn http(timeout: u64) -> Result<reqwest::blocking::Client> {
    crate::net::client()
        .timeout(Duration::from_secs(timeout))
        .connect_timeout(Duration::from_secs(10))
        .user_agent(concat!("KaradelikIPTVPlayer-updater/", env!("CARGO_PKG_VERSION")))
        .build()
        .map_err(|e| UpdateError::Network(e.to_string()))
}

/// The newest release if it is newer than [current]; None when up to date.
pub fn check(feed_url: &str, current: &str) -> Result<Option<Release>> {
    let resp = http(20)?.get(feed_url).send().map_err(|e| UpdateError::Network(e.to_string()))?;
    if !resp.status().is_success() {
        return Err(UpdateError::Network(format!("HTTP {}", resp.status().as_u16())));
    }
    let release: Release = resp.json().map_err(|_| UpdateError::BadFeed)?;
    if release.sha256.len() != 64 || !(release.url.starts_with("https://") || release.url.starts_with("http://127.0.0.1")) {
        // Only HTTPS installers (plus the local mock in development).
        return Err(UpdateError::BadFeed);
    }
    Ok(is_newer(&release.version, current).then_some(release))
}

/// Downloads the release's installer into [dir] and verifies it. A file
/// already there with the right hash is reused. [progress] gets 0.0..=1.0.
pub fn download(release: &Release, dir: &Path, progress: &dyn Fn(f64)) -> Result<PathBuf> {
    std::fs::create_dir_all(dir)?;
    let target = dir.join(format!("KaradelikIPTVPlayer-Setup-{}.exe", sanitize(&release.version)));
    if target.exists() && sha256_file(&target)?.eq_ignore_ascii_case(&release.sha256) {
        progress(1.0);
        return Ok(target);
    }
    let mut resp = http(1800)?.get(&release.url).send().map_err(|e| UpdateError::Network(e.to_string()))?;
    if !resp.status().is_success() {
        return Err(UpdateError::Network(format!("HTTP {}", resp.status().as_u16())));
    }
    let total = resp.content_length().unwrap_or(0);
    let part = target.with_extension("part");
    let mut file = std::fs::File::create(&part)?;
    let mut hasher = Sha256::new();
    let mut buf = vec![0u8; 256 * 1024];
    let mut done = 0u64;
    loop {
        let n = resp.read(&mut buf).map_err(|e| UpdateError::Network(e.to_string()))?;
        if n == 0 {
            break;
        }
        file.write_all(&buf[..n])?;
        hasher.update(&buf[..n]);
        done += n as u64;
        if total > 0 {
            progress(done as f64 / total as f64);
        }
    }
    file.sync_all()?;
    drop(file);
    if !hex(&hasher.finalize()).eq_ignore_ascii_case(&release.sha256) {
        let _ = std::fs::remove_file(&part);
        return Err(UpdateError::Checksum);
    }
    std::fs::rename(&part, &target)?;
    prune(dir, &target)?;
    progress(1.0);
    Ok(target)
}

/// Keeps the newest installer and the one before it (for going back).
fn prune(dir: &Path, keep: &Path) -> Result<()> {
    let mut installers: Vec<_> = std::fs::read_dir(dir)?
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.extension().is_some_and(|e| e == "exe") && p != keep)
        .collect();
    installers.sort_by_key(|p| std::fs::metadata(p).and_then(|m| m.modified()).ok());
    while installers.len() > 1 {
        let _ = std::fs::remove_file(installers.remove(0));
    }
    Ok(())
}

/// The installer kept from before the newest one, if any: for "go back".
pub fn previous_installer(dir: &Path, current: &str) -> Option<(String, PathBuf)> {
    let mut found: Vec<(String, PathBuf)> = std::fs::read_dir(dir)
        .ok()?
        .flatten()
        .filter_map(|e| {
            let p = e.path();
            let v = p.file_stem()?.to_str()?.strip_prefix("KaradelikIPTVPlayer-Setup-")?.to_string();
            (p.extension()? == "exe").then_some((v, p))
        })
        .filter(|(v, _)| is_newer(current, v))
        .collect();
    found.sort_by(|a, b| if is_newer(&a.0, &b.0) { std::cmp::Ordering::Greater } else { std::cmp::Ordering::Less });
    found.pop()
}

pub fn sha256_file(path: &Path) -> Result<String> {
    let mut f = std::fs::File::open(path)?;
    let mut hasher = Sha256::new();
    std::io::copy(&mut f, &mut hasher)?;
    Ok(hex(&hasher.finalize()))
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn sanitize(version: &str) -> String {
    version.chars().filter(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '-')).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn versions_compare_by_number_not_text() {
        assert!(is_newer("0.10.0", "0.9.9"));
        assert!(is_newer("v1.0.0", "0.9"));
        assert!(!is_newer("1.0.0", "1.0.0"));
        assert!(!is_newer("1.0.0-beta.1", "1.0.0"));
        assert!(is_newer("1.0.0", "1.0.0-beta.1"));
        assert!(!is_newer("0.9.9", "0.10.0"));
    }

    #[test]
    fn keeps_the_newest_two_and_finds_the_previous_one() {
        let dir = tempfile::tempdir().unwrap();
        for v in ["0.1.0", "0.2.0", "0.3.0"] {
            std::fs::write(dir.path().join(format!("KaradelikIPTVPlayer-Setup-{v}.exe")), v).unwrap();
            std::thread::sleep(std::time::Duration::from_millis(20));
        }
        let newest = dir.path().join("KaradelikIPTVPlayer-Setup-0.3.0.exe");
        prune(dir.path(), &newest).unwrap();
        let left: Vec<_> = std::fs::read_dir(dir.path()).unwrap().flatten().map(|e| e.file_name().into_string().unwrap()).collect();
        assert_eq!(left.len(), 2, "{left:?}");
        let (v, _) = previous_installer(dir.path(), "0.3.0").unwrap();
        assert_eq!(v, "0.2.0");
        assert!(previous_installer(dir.path(), "0.2.0").is_none(), "nothing older than 0.2.0 kept");
    }

    /// A tiny HTTP server on 127.0.0.1 answering [routes] (path, body); the
    /// routes get the server's own address so the feed can point back at it.
    fn serve(routes: impl FnOnce(&str) -> Vec<(&'static str, Vec<u8>)>) -> String {
        use std::io::{BufRead, BufReader};
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let base = format!("http://127.0.0.1:{}", listener.local_addr().unwrap().port());
        let table = routes(&base);
        std::thread::spawn(move || {
            for stream in listener.incoming().flatten() {
                let mut reader = BufReader::new(stream.try_clone().unwrap());
                let mut line = String::new();
                reader.read_line(&mut line).unwrap();
                let path = line.split_whitespace().nth(1).unwrap_or("/").to_string();
                // Skip the headers.
                loop {
                    let mut h = String::new();
                    if reader.read_line(&mut h).unwrap_or(0) <= 2 {
                        break;
                    }
                }
                let mut out = stream;
                match table.iter().find(|(p, _)| *p == path) {
                    Some((_, body)) => {
                        let _ = write!(out, "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n", body.len());
                        let _ = out.write_all(body);
                    }
                    None => {
                        let _ = write!(out, "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
                    }
                }
            }
        });
        base
    }

    #[test]
    fn checks_downloads_verifies_and_reuses() {
        let installer = vec![7u8; 300_000];
        let routes = |sha: String| {
            let installer = installer.clone();
            move |base: &str| {
                vec![
                    ("/latest.json", format!(r#"{{"version":"0.2.0","url":"{base}/setup.exe","sha256":"{sha}","notes":{{"tr":"Yeni"}}}}"#).into_bytes()),
                    ("/setup.exe", installer),
                ]
            }
        };

        let base = serve(routes(hex(&Sha256::digest(&installer))));
        assert!(check(&format!("{base}/latest.json"), "0.2.0").unwrap().is_none(), "same version: up to date");
        let release = check(&format!("{base}/latest.json"), "0.1.0").unwrap().expect("newer");
        assert_eq!(release.notes_for("en"), "Yeni");

        let dir = tempfile::tempdir().unwrap();
        let steps = std::cell::RefCell::new(Vec::new());
        let path = download(&release, dir.path(), &|f| steps.borrow_mut().push(f)).unwrap();
        assert_eq!(std::fs::read(&path).unwrap(), installer);
        assert_eq!(*steps.borrow().last().unwrap(), 1.0);
        // Already there and intact: not downloaded again.
        let calls = std::cell::Cell::new(0);
        download(&release, dir.path(), &|_| calls.set(calls.get() + 1)).unwrap();
        assert_eq!(calls.get(), 1, "only the final 1.0");

        // A feed whose hash does not match the file: refused, nothing kept.
        let bad = serve(routes("0".repeat(64)));
        let tampered = check(&format!("{bad}/latest.json"), "0.1.0").unwrap().unwrap();
        let fresh = tempfile::tempdir().unwrap();
        assert!(matches!(download(&tampered, fresh.path(), &|_| {}), Err(UpdateError::Checksum)));
        assert_eq!(std::fs::read_dir(fresh.path()).unwrap().count(), 0, "nothing left behind");
    }

    #[test]
    fn notes_fall_back_to_any_language() {
        let r = Release {
            version: "1".into(),
            url: String::new(),
            sha256: String::new(),
            notes: [("tr".to_string(), "Türkçe".to_string())].into(),
            published: None,
        };
        assert_eq!(r.notes_for("en"), "Türkçe");
        assert_eq!(r.notes_for("tr"), "Türkçe");
    }
}
