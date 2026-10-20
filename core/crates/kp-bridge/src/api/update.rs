//! App updates for the UI: check the feed, download with progress, install.

use std::path::PathBuf;
use std::sync::Mutex;

use anyhow::{anyhow, Result};
use kp_core::update::{self, Release};

use super::library::core;
use crate::frb_generated::StreamSink;

/// The release found by the last check, ready to download.
static PENDING: Mutex<Option<Release>> = Mutex::new(None);

#[derive(Debug, Clone)]
pub struct UpdateInfo {
    pub version: String,
    pub notes: String,
    pub published: Option<String>,
}

#[derive(Debug, Clone)]
pub enum UpdateProgress {
    Downloading { fraction: f64 },
    /// Verified and ready: pass `path` to [install_update].
    Ready { path: String },
    Failed { message: String },
}

/// The newer release named by [feed_url], or None when [current] is newest.
pub fn check_update(feed_url: String, current: String, language: String) -> Result<Option<UpdateInfo>> {
    let found = update::check(&feed_url, &current)?;
    let info = found.as_ref().map(|r| UpdateInfo { version: r.version.clone(), notes: r.notes_for(&language), published: r.published.clone() });
    *PENDING.lock().unwrap_or_else(|p| p.into_inner()) = found;
    Ok(info)
}

/// Downloads and verifies the release from the last check. The stream ends
/// with `Ready` or `Failed`.
pub fn download_update(sink: StreamSink<UpdateProgress>) -> Result<()> {
    let Some(release) = PENDING.lock().unwrap_or_else(|p| p.into_inner()).clone() else {
        let _ = sink.add(UpdateProgress::Failed { message: "no update pending".into() });
        return Ok(());
    };
    let dir = core()?.updates_dir();
    let progress = |f: f64| {
        let _ = sink.add(UpdateProgress::Downloading { fraction: f });
    };
    let _ = match update::download(&release, &dir, &progress) {
        Ok(path) => sink.add(UpdateProgress::Ready { path: path.to_string_lossy().into_owned() }),
        Err(e) => sink.add(UpdateProgress::Failed { message: e.to_string() }),
    };
    Ok(())
}

/// Starts the installer detached, silently, told to reopen the app; the
/// caller quits right after so its files can be replaced.
pub fn install_update(path: String) -> Result<()> {
    let path = PathBuf::from(path);
    if !path.is_file() {
        return Err(anyhow!("installer not found"));
    }
    let mut cmd = std::process::Command::new(&path);
    cmd.args(["/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/CLOSEAPPLICATIONS", "/LAUNCH=1"]);
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        const DETACHED_PROCESS: u32 = 0x0000_0008;
        const CREATE_NEW_PROCESS_GROUP: u32 = 0x0000_0200;
        cmd.creation_flags(DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP);
    }
    cmd.spawn()?;
    Ok(())
}

/// The version before [current] that can be reinstalled, if its installer
/// was kept: (version, installer path).
pub fn previous_version(current: String) -> Result<Option<(String, String)>> {
    Ok(update::previous_installer(&core()?.updates_dir(), &current).map(|(v, p)| (v, p.to_string_lossy().into_owned())))
}
