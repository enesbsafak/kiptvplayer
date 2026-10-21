//! The data core's public face: everything the UI asks for goes through here.
//!
//! Calls are synchronous; the bridge runs them on its worker pool, never on
//! the UI thread. Network work happens in `add_source` / `sync` / detail
//! fetches; every list call reads SQLite only, so screens paint instantly.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use serde_json::Value;

use crate::catalog::{Catalog, ContentKind, XtreamLists};
use crate::guide::{Guide, GuideError};
use crate::lang::t;
use crate::secret::{password_key, SecretStore};
use crate::tmdb::{Media, Tmdb, TmdbDetail, TmdbEpisode, TmdbError};
use crate::store::{CategoryRow, ChannelRow, EpgRow, ItemRow, ProgressRow, ReminderRow, SourceRow, Store, StoreError};
use crate::xtream::{as_array, as_i64, as_string, XtreamClient, XtreamError};

#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error("{0}")]
    Xtream(#[from] XtreamError),
    #[error("{}: {}", crate::lang::t("veritabanı hatası", "database error"), .0)]
    Store(#[from] StoreError),
    #[error("{0}")]
    Tmdb(#[from] TmdbError),
    #[error("{0}")]
    Guide(#[from] GuideError),
    #[error("{0}")]
    Stalker(#[from] crate::stalker::StalkerError),
    #[error("{0}")]
    Message(String),
}

pub type Result<T> = std::result::Result<T, CoreError>;

fn msg(s: impl Into<String>) -> CoreError {
    CoreError::Message(s.into())
}

#[derive(Debug, Clone, PartialEq)]
pub enum SourceKind {
    Xtream,
    M3u,
    /// Stalker / Ministra portal: `url` is the portal, `password` the MAC.
    Stalker,
}

#[derive(Debug, Clone)]
pub struct NewSource {
    pub kind: SourceKind,
    pub name: String,
    /// Xtream server URL, or M3U playlist URL / local file path.
    pub url: String,
    pub username: Option<String>,
    pub password: Option<String>,
    pub epg_url: Option<String>,
    pub user_agent: Option<String>,
    pub insecure_tls: bool,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct SyncSummary {
    pub live: u64,
    pub movies: u64,
    pub series: u64,
}

#[derive(Debug, Clone, PartialEq)]
pub enum SyncStage {
    Connecting,
    Downloading { what: String },
    Saving,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlaybackInfo {
    pub url: String,
    pub title: String,
    pub is_live: bool,
    pub user_agent: Option<String>,
    pub referrer: Option<String>,
    /// Resume point for VOD, if the user stopped half-way.
    pub resume_ms: Option<i64>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Programme {
    pub start: i64,
    pub stop: i64,
    pub title: String,
    pub description: String,
    /// Can be played back now (catch-up).
    pub archive: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Episode {
    pub ext_id: i64,
    pub season: i32,
    pub number: i32,
    pub title: String,
    pub plot: Option<String>,
    pub image: Option<String>,
    pub duration_secs: Option<i64>,
    pub container: String,
    pub progress_ms: Option<i64>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Detail {
    pub item: ItemRow,
    pub plot: Option<String>,
    pub genre: Option<String>,
    pub cast: Option<String>,
    pub director: Option<String>,
    pub duration_secs: Option<i64>,
    pub backdrop: Option<String>,
    pub trailer: Option<String>,
    pub episodes: Vec<Episode>,
    pub is_favorite: bool,
    pub progress_ms: Option<i64>,
}

/// TMDB data changes rarely: details are reused for two weeks, and a title
/// without a match is not searched again for a week.
const TMDB_TTL_SECS: i64 = 14 * 86_400;
const TMDB_MISS_TTL_SECS: i64 = 7 * 86_400;
const TMDB_KEY: &str = "tmdb:api-key";

#[derive(Debug, Clone, PartialEq)]
pub struct TmdbStatus {
    pub configured: bool,
    /// "tr-TR", "en-US": the language TMDB answers in.
    pub language: String,
}

/// Short EPG is refetched after this long.
const EPG_TTL_SECS: i64 = 30 * 60;

pub struct Core {
    store: Mutex<Store>,
    secrets: Box<dyn SecretStore>,
    /// Where XMLTV guides live (`guide-<source>.sqlite`), beside the library.
    dir: PathBuf,
    /// Open guides by source id.
    guides: Mutex<HashMap<String, Option<Guide>>>,
    /// Portal sessions by source id: a handshake per channel change would
    /// cost a round trip every zap.
    portals: Mutex<HashMap<String, std::sync::Arc<crate::stalker::StalkerClient>>>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct GuideStatus {
    pub ok: bool,
    /// Programmes stored, or the error.
    pub programmes: u64,
    pub matched: u64,
    pub channels: u64,
    pub error: Option<String>,
    pub at: i64,
}

pub fn now() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
}

impl Core {
    pub fn open(db_path: impl AsRef<Path>, secrets: Box<dyn SecretStore>) -> Result<Self> {
        let db_path = db_path.as_ref();
        let dir = db_path.parent().map(Path::to_path_buf).unwrap_or_else(|| PathBuf::from("."));
        Ok(Core { store: Mutex::new(Store::open(db_path)?), secrets, dir, guides: Mutex::default(), portals: Mutex::default() })
    }

    /// Tests: the library in memory, guides in a fresh temp folder.
    pub fn open_in_memory(secrets: Box<dyn SecretStore>) -> Result<Self> {
        let nanos = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
        let dir = std::env::temp_dir().join(format!("kp-core-{}-{nanos}", std::process::id()));
        std::fs::create_dir_all(&dir).map_err(|e| msg(e.to_string()))?;
        Ok(Core { store: Mutex::new(Store::open_in_memory()?), secrets, dir, guides: Mutex::default(), portals: Mutex::default() })
    }

    fn store(&self) -> std::sync::MutexGuard<'_, Store> {
        // A panic while holding the lock leaves SQLite consistent (every
        // write is transactional), so a poisoned lock is safe to reuse.
        self.store.lock().unwrap_or_else(|p| p.into_inner())
    }

    // ---- sources -------------------------------------------------------

    /// Validates the source against the provider, stores it (password in the
    /// OS credential store) and runs the first sync.
    pub fn add_source(&self, new: NewSource, on_stage: &dyn Fn(SyncStage)) -> Result<(SourceRow, SyncSummary)> {
        let name = new.name.trim();
        if new.url.trim().is_empty() {
            return Err(msg(t("Adres boş olamaz", "The address cannot be empty")));
        }
        let id = format!("s{:x}", xxhash_rust::xxh3::xxh3_64(format!("{}|{}|{}", new.url, new.username.as_deref().unwrap_or(""), now()).as_bytes()));
        let row = SourceRow {
            id: id.clone(),
            kind: match new.kind {
                SourceKind::Xtream => "xtream".into(),
                SourceKind::M3u => "m3u".into(),
                SourceKind::Stalker => "stalker".into(),
            },
            name: if name.is_empty() { default_name(&new.url) } else { name.to_string() },
            url: match new.kind {
                SourceKind::Xtream => crate::xtream::normalize_base(&new.url),
                SourceKind::M3u | SourceKind::Stalker => new.url.trim().to_string(),
            },
            username: new.username.clone().filter(|u| !u.trim().is_empty()),
            epg_url: new.epg_url.clone().filter(|u| !u.trim().is_empty()),
            user_agent: new.user_agent.clone().filter(|u| !u.trim().is_empty()),
            insecure_tls: new.insecure_tls,
            synced_at: None,
            last_error: None,
            expires_at: None,
            max_connections: None,
            timezone: None,
        };

        if new.kind == SourceKind::Xtream {
            let password = new.password.clone().unwrap_or_default();
            let user = row.username.clone().ok_or_else(|| msg(t("Kullanıcı adı gerekli", "A username is required")))?;
            on_stage(SyncStage::Connecting);
            let client = XtreamClient::new(&row.url, &user, &password, row.user_agent.as_deref(), row.insecure_tls)?;
            client.account()?;
            self.secrets.set(&password_key(&id), &password).map_err(|e| msg(format!("{}: {e}", t("Şifre kaydedilemedi", "Could not save the password"))))?;
        }
        if new.kind == SourceKind::Stalker {
            // The MAC is the subscription's credential: keyring, like a password.
            let mac = crate::stalker::normalize_mac(new.password.as_deref().unwrap_or(""))?;
            on_stage(SyncStage::Connecting);
            let client = crate::stalker::StalkerClient::connect(&row.url, &mac, &local_timezone(), row.insecure_tls)?;
            self.portals.lock().unwrap_or_else(|p| p.into_inner()).insert(id.clone(), std::sync::Arc::new(client));
            self.secrets.set(&password_key(&id), &mac).map_err(|e| msg(format!("{}: {e}", t("Şifre kaydedilemedi", "Could not save the password"))))?;
        }

        self.store().upsert_source(&row)?;
        match self.sync(&id, on_stage) {
            Ok(summary) => Ok((self.store().source(&id)?.unwrap_or(row), summary)),
            Err(e) => {
                // A source that never synced is useless; don't leave it behind.
                self.store().delete_source(&id)?;
                self.secrets.delete(&password_key(&id));
                Err(e)
            }
        }
    }

    pub fn sources(&self) -> Result<Vec<SourceRow>> {
        Ok(self.store().sources()?)
    }

    pub fn delete_source(&self, id: &str) -> Result<()> {
        self.store().delete_source(id)?;
        self.secrets.delete(&password_key(id));
        let mut guides = self.guides.lock().unwrap_or_else(|p| p.into_inner());
        guides.remove(id);
        let _ = std::fs::remove_file(self.guide_path(id));
        self.portals.lock().unwrap_or_else(|p| p.into_inner()).remove(id);
        Ok(())
    }

    /// Where downloaded app updates are kept (beside the library).
    pub fn updates_dir(&self) -> PathBuf {
        self.dir.join("updates")
    }

    // ---- XMLTV guide ------------------------------------------------------

    fn guide_path(&self, source_id: &str) -> PathBuf {
        self.dir.join(format!("guide-{source_id}.sqlite"))
    }

    /// Downloads the source's XMLTV guide (`url-tvg` or the URL the user
    /// gave) and swaps it in. The library is never locked meanwhile.
    pub fn refresh_guide(&self, source_id: &str) -> Result<GuideStatus> {
        let source = self.store().source(source_id)?.ok_or_else(|| msg(t("Kaynak bulunamadı", "Source not found")))?;
        let Some(url) = source.epg_url.clone().filter(|u| !u.trim().is_empty()) else {
            return Err(msg(t("Bu kaynak için yayın akışı adresi yok", "This source has no TV guide address")));
        };
        let t = now();
        let result = (|| -> Result<crate::guide::BuildStats> {
            let input = open_guide(&url, &source)?;
            let channels = self.store().guide_channels(source_id)?;
            let path = self.guide_path(source_id);
            let stats = crate::guide::build(&path, input, &channels, t)?;
            let mut guides = self.guides.lock().unwrap_or_else(|p| p.into_inner());
            guides.remove(source_id); // closes the old file so it can be replaced
            crate::guide::install(&path)?;
            Ok(stats)
        })();
        let status = match result {
            Ok(s) => GuideStatus { ok: true, programmes: s.programmes, matched: s.matched, channels: s.channels, error: None, at: t },
            Err(e) => GuideStatus { ok: false, programmes: 0, matched: 0, channels: 0, error: Some(e.to_string()), at: t },
        };
        self.store().set_setting(&format!("guide:{source_id}"), &encode_guide_status(&status))?;
        if let Some(e) = &status.error {
            return Err(msg(e.clone()));
        }
        Ok(status)
    }

    /// The last guide download's outcome; None if there never was one.
    pub fn guide_status(&self, source_id: &str) -> Result<Option<GuideStatus>> {
        Ok(self.store().setting(&format!("guide:{source_id}"))?.and_then(|s| decode_guide_status(&s)))
    }

    /// Guide programmes for [item] overlapping [from]..[to], with its tvg-shift.
    fn guide_programmes(&self, item: &ItemRow, from: i64, to: i64, limit: u32) -> Result<Vec<EpgRow>> {
        let mut guides = self.guides.lock().unwrap_or_else(|p| p.into_inner());
        if !guides.contains_key(&item.source_id) {
            let g = Guide::open(&self.guide_path(&item.source_id))?;
            guides.insert(item.source_id.clone(), g);
        }
        let Some(Some(guide)) = guides.get(&item.source_id) else { return Ok(Vec::new()) };
        let shift = (item.tvg_shift.unwrap_or(0.0) * 3600.0).round() as i64;
        Ok(guide.programmes(item.uid, from, to, shift, limit)?)
    }

    /// Downloads the source's catalog and swaps it in atomically. Readers
    /// keep seeing the old catalog until the new one is fully written.
    pub fn sync(&self, source_id: &str, on_stage: &dyn Fn(SyncStage)) -> Result<SyncSummary> {
        let source = self.store().source(source_id)?.ok_or_else(|| msg(t("Kaynak bulunamadı", "Source not found")))?;
        let result = self.download_catalog(&source, on_stage);
        match result {
            Ok((catalog, account)) => {
                on_stage(SyncStage::Saving);
                let summary = {
                    let mut store = self.store();
                    store.replace_catalog(source_id, &catalog, now())?;
                    if let Some(a) = account {
                        store.set_source_status(source_id, None, a.expires_at, a.max_connections, a.server_timezone.as_deref())?;
                    }
                    SyncSummary {
                        live: store.count_by_kind(source_id, ContentKind::Live)?,
                        movies: store.count_by_kind(source_id, ContentKind::Movie)?,
                        series: store.count_by_kind(source_id, ContentKind::Series)?,
                    }
                };
                // M3U guides come from XMLTV. A guide failure is recorded in
                // its status but never fails the source: channels still play.
                let has_guide = self.store().source(source_id)?.is_some_and(|s| s.kind != "xtream" && s.epg_url.is_some());
                if has_guide {
                    on_stage(SyncStage::Downloading { what: t("Yayın akışı", "TV guide").into() });
                    let _ = self.refresh_guide(source_id);
                }
                Ok(summary)
            }
            Err(e) => {
                self.store().set_source_status(source_id, Some(&e.to_string()), None, None, None)?;
                Err(e)
            }
        }
    }

    fn download_catalog(&self, source: &SourceRow, on_stage: &dyn Fn(SyncStage)) -> Result<(Catalog, Option<crate::xtream::AccountInfo>)> {
        on_stage(SyncStage::Connecting);
        if source.kind == "stalker" {
            let portal = self.portal(source)?;
            on_stage(SyncStage::Downloading { what: t("Canlı kanallar", "live channels").into() });
            let (genres, channels) = (portal.genres()?, portal.channels()?);
            on_stage(SyncStage::Downloading { what: t("Filmler", "movies").into() });
            // A portal without a video library (or a broken one) still gives live TV.
            let vod_categories = portal.vod_categories().unwrap_or_default();
            let movies = portal.movies(&vod_categories).unwrap_or_default();
            let catalog = Catalog::from_stalker(&genres, &channels, &vod_categories, &movies);
            if catalog.channels.is_empty() {
                return Err(msg(t("Portal kanal listesi boş", "The portal lists no channels")));
            }
            let account = crate::xtream::AccountInfo {
                status: String::new(),
                expires_at: portal.expires_at(),
                max_connections: None,
                active_connections: None,
                is_trial: false,
                server_timezone: None,
            };
            return Ok((catalog, Some(account)));
        }
        if source.kind == "xtream" {
            let client = self.xtream(source)?;
            let account = client.account()?;
            let mut lists = Vec::new();
            for (kind, label) in [
                (ContentKind::Live, t("Canlı kanallar", "live channels")),
                (ContentKind::Movie, t("Filmler", "movies")),
                (ContentKind::Series, t("Diziler", "series")),
            ] {
                on_stage(SyncStage::Downloading { what: label.into() });
                lists.push(XtreamLists { kind, categories: client.categories(kind)?, items: client.items(kind)? });
            }
            Ok((Catalog::from_xtream(lists), Some(account)))
        } else {
            on_stage(SyncStage::Downloading { what: t("Oynatma listesi", "Playlist").into() });
            let text = fetch_playlist(source)?;
            let catalog = Catalog::from_m3u(crate::m3u::parse(&text));
            if catalog.channels.is_empty() {
                return Err(msg(t("Listede oynatılabilir kanal bulunamadı", "The playlist has no playable channels")));
            }
            Ok((catalog, None))
        }
    }

    /// "Is it the provider?": one light request to the source (Xtream
    /// account, portal account page, the playlist's headers), timed, with
    /// what the provider says about the account. Never opens a stream, so
    /// it does not take a connection away from the one playing.
    pub fn check_source(&self, source_id: &str) -> Result<SourceHealth> {
        let source = self.store().source(source_id)?.ok_or_else(|| msg(t("Kaynak bulunamadı", "Source not found")))?;
        let started = std::time::Instant::now();
        let mut health = SourceHealth::default();
        let outcome: Result<()> = (|| {
            match source.kind.as_str() {
                "xtream" => {
                    let a = self.xtream(&source)?.account()?;
                    health.status = Some(a.status).filter(|s| !s.is_empty());
                    health.expires_at = a.expires_at;
                    health.max_connections = a.max_connections;
                    health.active_connections = a.active_connections;
                }
                "stalker" => health.expires_at = self.portal(&source)?.main_info()?,
                _ => probe_playlist(&source)?,
            }
            Ok(())
        })();
        health.latency_ms = started.elapsed().as_millis().min(u32::MAX as u128) as u32;
        match outcome {
            Ok(()) => health.ok = true,
            Err(e) => health.error = Some(e.to_string()),
        }
        Ok(health)
    }

    /// The portal session for [source], opened (handshake) on first use.
    fn portal(&self, source: &SourceRow) -> Result<std::sync::Arc<crate::stalker::StalkerClient>> {
        if let Some(p) = self.portals.lock().unwrap_or_else(|p| p.into_inner()).get(&source.id) {
            return Ok(p.clone());
        }
        let mac = self
            .secrets
            .get(&password_key(&source.id))
            .ok_or_else(|| msg(t("Bu kaynağın şifresi bulunamadı; kaynağı yeniden ekleyin", "This source's password is missing; add the source again")))?;
        let client = std::sync::Arc::new(crate::stalker::StalkerClient::connect(&source.url, &mac, &local_timezone(), source.insecure_tls)?);
        self.portals.lock().unwrap_or_else(|p| p.into_inner()).insert(source.id.clone(), client.clone());
        Ok(client)
    }

    fn xtream(&self, source: &SourceRow) -> Result<XtreamClient> {
        let password = self
            .secrets
            .get(&password_key(&source.id))
            .ok_or_else(|| msg(t("Bu kaynağın şifresi bulunamadı; kaynağı yeniden ekleyin", "This source's password is missing; add the source again")))?;
        Ok(XtreamClient::new(
            &source.url,
            source.username.as_deref().unwrap_or(""),
            &password,
            source.user_agent.as_deref(),
            source.insecure_tls,
        )?)
    }

    // ---- browsing (SQLite only) -----------------------------------------

    pub fn categories(&self, source_id: &str, kind: ContentKind) -> Result<Vec<CategoryRow>> {
        Ok(self.store().categories(source_id, kind)?)
    }

    pub fn page(&self, source_id: &str, kind: ContentKind, category: Option<i64>, after_sort: Option<u32>, limit: u32) -> Result<Vec<ChannelRow>> {
        Ok(self.store().channels_page(source_id, kind, category, after_sort, limit)?)
    }

    /// Backup streams for a live channel that stopped playing.
    pub fn alternates(&self, item_id: i64) -> Result<Vec<ChannelRow>> {
        let item = self.item(item_id)?;
        if item.kind != ContentKind::Live {
            return Ok(Vec::new());
        }
        Ok(self.store().alternates(&item.source_id, item.uid)?)
    }

    pub fn search(&self, query: &str, kind: Option<ContentKind>, limit: u32) -> Result<Vec<ChannelRow>> {
        Ok(self.store().search(query, kind, limit)?)
    }

    pub fn recently_added(&self, source_id: &str, kind: ContentKind, limit: u32) -> Result<Vec<ChannelRow>> {
        Ok(self.store().recently_added(source_id, kind, limit)?)
    }

    pub fn favorites(&self, source_id: &str, kind: ContentKind) -> Result<Vec<ChannelRow>> {
        Ok(self.store().favorites(source_id, kind)?)
    }

    pub fn recent(&self, source_id: &str, kind: ContentKind, limit: u32) -> Result<Vec<ChannelRow>> {
        Ok(self.store().recent(source_id, kind, limit)?)
    }

    pub fn clear_history(&self, source_id: &str, recent: bool, progress: bool) -> Result<()> {
        Ok(self.store().clear_history(source_id, recent, progress)?)
    }

    pub fn continue_watching(&self, source_id: &str, limit: u32) -> Result<Vec<ProgressRow>> {
        Ok(self.store().continue_watching(source_id, limit)?)
    }

    pub fn item(&self, id: i64) -> Result<ItemRow> {
        self.store().item(id)?.ok_or_else(|| msg(t("İçerik bulunamadı", "Item not found")))
    }

    pub fn item_by_uid(&self, source_id: &str, uid: i64) -> Result<Option<ItemRow>> {
        Ok(self.store().item_by_uid(source_id, uid)?)
    }

    pub fn is_favorite(&self, item_id: i64) -> Result<bool> {
        let item = self.item(item_id)?;
        Ok(self.store().is_favorite(&item.source_id, item.uid)?)
    }

    pub fn count(&self, source_id: &str, kind: ContentKind) -> Result<u64> {
        Ok(self.store().count_by_kind(source_id, kind)?)
    }

    // ---- preferences ---------------------------------------------------

    /// The region shown first, and whether the user (or first run) ever
    /// chose one; `(false, None)` means "decide from the OS locale".
    pub fn region_preference(&self) -> Result<(bool, Option<String>)> {
        let store = self.store();
        let chosen = store.setting("region")?.is_some();
        Ok((chosen, store.region_pref().map(String::from)))
    }

    pub fn set_region_preference(&self, region: Option<&str>) -> Result<()> {
        Ok(self.store().set_region_pref(region)?)
    }

    /// Regions present in a source, with how many items carry each.
    pub fn regions(&self, source_id: &str) -> Result<Vec<(String, u32)>> {
        Ok(self.store().regions(source_id)?)
    }

    pub fn set_reminder(&self, item_id: i64, reminder: &ReminderRow, on: bool) -> Result<()> {
        let item = self.item(item_id)?;
        Ok(self.store().set_reminder(&item.source_id, item.uid, reminder, on)?)
    }

    pub fn reminders(&self, source_id: &str) -> Result<Vec<(ChannelRow, ReminderRow)>> {
        Ok(self.store().reminders(source_id, now())?)
    }

    pub fn set_favorite(&self, item_id: i64, on: bool) -> Result<()> {
        let item = self.item(item_id)?;
        Ok(self.store().set_favorite(&item.source_id, item.uid, on, now())?)
    }

    pub fn save_progress(&self, item_id: i64, episode_id: Option<i64>, title: &str, position_ms: i64, duration_ms: i64) -> Result<()> {
        let item = self.item(item_id)?;
        Ok(self.store().save_progress(&ProgressRow {
            source_id: item.source_id,
            uid: episode_id.unwrap_or(item.uid),
            item_uid: item.uid,
            title: title.to_string(),
            position_ms,
            duration_ms,
            updated_at: now(),
        })?)
    }

    // ---- playback ------------------------------------------------------

    /// Resolves what mpv should open. Marks the item as recently watched.
    pub fn playback(&self, item_id: i64, episode: Option<(i64, String)>) -> Result<PlaybackInfo> {
        let item = self.item(item_id)?;
        let source = self.store().source(&item.source_id)?.ok_or_else(|| msg(t("Kaynak bulunamadı", "Source not found")))?;
        let resume_key = episode.as_ref().map(|e| e.0).unwrap_or(item.uid);
        let resume_ms = self.store().progress(&item.source_id, resume_key)?.map(|p| p.position_ms).filter(|p| *p > 5_000);

        let url = if let Some(cmd) = item.url.strip_prefix("stalker:") {
            // Portal links expire: ask for a fresh one now.
            self.portal(&source)?.create_link(cmd)?
        } else if let Some(cmd) = item.url.strip_prefix("stalker-vod:") {
            self.portal(&source)?.create_vod_link(cmd)?
        } else if let Some(rest) = item.url.strip_prefix("xtream:") {
            let client = self.xtream(&source)?;
            let id = item.ext_id.ok_or_else(|| msg(t("Geçersiz içerik", "Invalid item")))?;
            match (rest.split(':').next(), &episode) {
                (_, Some((episode_id, container))) => client.episode_url(*episode_id, container),
                (Some("live"), None) => client.live_url(id, "ts"),
                (Some("movie"), None) => client.movie_url(id, item.container.as_deref().unwrap_or("mp4")),
                _ => return Err(msg(t("Diziler için bölüm seçin", "Choose an episode of the series"))),
            }
        } else {
            item.url.clone()
        };

        self.store().touch_recent(&item.source_id, item.uid, now())?;
        Ok(PlaybackInfo {
            url,
            title: item.name.clone(),
            is_live: item.kind == ContentKind::Live,
            user_agent: item.user_agent.clone().or(source.user_agent.clone()),
            referrer: item.referrer.clone(),
            resume_ms,
        })
    }

    // ---- details & EPG (network, cached) --------------------------------

    pub fn detail(&self, item_id: i64) -> Result<Detail> {
        let item = self.item(item_id)?;
        let (is_favorite, progress_ms) = {
            let store = self.store();
            (store.is_favorite(&item.source_id, item.uid)?, store.progress(&item.source_id, item.uid)?.map(|p| p.position_ms))
        };
        let mut detail = Detail {
            plot: None,
            genre: None,
            cast: None,
            director: None,
            duration_secs: None,
            backdrop: None,
            trailer: None,
            episodes: Vec::new(),
            is_favorite,
            progress_ms,
            item: item.clone(),
        };
        if !item.url.starts_with("xtream:") || item.kind == ContentKind::Live {
            return Ok(detail);
        }
        let source = self.store().source(&item.source_id)?.ok_or_else(|| msg(t("Kaynak bulunamadı", "Source not found")))?;
        let client = self.xtream(&source)?;
        let ext = item.ext_id.ok_or_else(|| msg(t("Geçersiz içerik", "Invalid item")))?;
        let v = if item.kind == ContentKind::Series { client.series_info(ext)? } else { client.vod_info(ext)? };
        let info = v.get("info").cloned().unwrap_or(Value::Null);
        detail.plot = as_string(info.get("plot")).or_else(|| as_string(info.get("description")));
        detail.genre = as_string(info.get("genre"));
        detail.cast = as_string(info.get("cast")).or_else(|| as_string(info.get("actors")));
        detail.director = as_string(info.get("director"));
        detail.duration_secs = as_i64(info.get("duration_secs")).or_else(|| as_i64(info.get("episode_run_time")).map(|m| m * 60));
        detail.backdrop = match info.get("backdrop_path") {
            Some(Value::Array(a)) => a.iter().find_map(|v| as_string(Some(v))),
            other => as_string(other),
        };
        detail.trailer = as_string(info.get("youtube_trailer"));

        if item.kind == ContentKind::Series {
            let store = self.store();
            if let Some(Value::Object(seasons)) = v.get("episodes") {
                for (season_key, list) in seasons {
                    for e in as_array(list.clone()) {
                        let Some(ext_id) = as_i64(e.get("id")) else { continue };
                        let einfo = e.get("info").cloned().unwrap_or(Value::Null);
                        detail.episodes.push(Episode {
                            ext_id,
                            season: as_i64(e.get("season")).or_else(|| season_key.parse().ok()).unwrap_or(1) as i32,
                            number: as_i64(e.get("episode_num")).unwrap_or(0) as i32,
                            title: as_string(e.get("title")).unwrap_or_else(|| format!("Bölüm {}", as_i64(e.get("episode_num")).unwrap_or(0))),
                            plot: as_string(einfo.get("plot")),
                            image: as_string(einfo.get("movie_image")),
                            duration_secs: as_i64(einfo.get("duration_secs")),
                            container: as_string(e.get("container_extension")).unwrap_or_else(|| "mp4".into()),
                            progress_ms: store.progress(&item.source_id, ext_id)?.map(|p| p.position_ms),
                        });
                    }
                }
            }
            detail.episodes.sort_by_key(|e| (e.season, e.number));
        }
        Ok(detail)
    }

    // ---- TMDB ----------------------------------------------------------

    pub fn tmdb_status(&self) -> Result<TmdbStatus> {
        Ok(TmdbStatus { configured: self.secrets.get(TMDB_KEY).is_some(), language: self.tmdb_language()? })
    }

    /// The TMDB language the user picked, else the app's language.
    fn tmdb_language(&self) -> Result<String> {
        let default = if crate::lang::is_english() { "en-US" } else { "tr-TR" };
        Ok(self.store().setting("tmdb_language")?.filter(|l| !l.is_empty()).unwrap_or_else(|| default.into()))
    }

    /// The app language the user chose; None follows the system.
    pub fn ui_language(&self) -> Result<Option<String>> {
        Ok(self.store().setting("ui_language")?.filter(|l| !l.is_empty()))
    }

    /// Stores the user's choice (None = system) and switches the core's
    /// messages to [effective], the language the app ended up using.
    pub fn set_ui_language(&self, choice: Option<&str>, effective: &str) -> Result<()> {
        self.store().set_setting("ui_language", choice.unwrap_or(""))?;
        crate::lang::set_language(effective);
        Ok(())
    }

    /// Saves (after checking it with TMDB) or, with None, forgets the key.
    /// v3 API keys and v4 read access tokens both work.
    pub fn set_tmdb_key(&self, key: Option<&str>) -> Result<()> {
        match key.map(str::trim).filter(|k| !k.is_empty()) {
            None => self.secrets.delete(TMDB_KEY),
            Some(k) => {
                Tmdb::new(k, &self.tmdb_language()?, tmdb_base().as_deref())?.validate()?;
                self.secrets.set(TMDB_KEY, k).map_err(|e| msg(format!("{}: {e}", t("Anahtar kaydedilemedi", "Could not save the key"))))?;
            }
        }
        Ok(())
    }

    pub fn set_tmdb_language(&self, language: &str) -> Result<()> {
        Ok(self.store().set_setting("tmdb_language", language)?)
    }

    fn tmdb(&self) -> Result<Option<Tmdb>> {
        let Some(key) = self.secrets.get(TMDB_KEY) else { return Ok(None) };
        Ok(Some(Tmdb::new(&key, &self.tmdb_language()?, tmdb_base().as_deref())?))
    }

    /// TMDB's view of a film or series, matched by title and year; None
    /// without a key, for live channels, or when TMDB has no match. Separate
    /// from [detail] so provider data never waits on TMDB.
    pub fn tmdb_for(&self, item_id: i64) -> Result<Option<TmdbDetail>> {
        let item = self.item(item_id)?;
        let media = match item.kind {
            ContentKind::Movie => Media::Movie,
            ContentKind::Series => Media::Tv,
            ContentKind::Live => return Ok(None),
        };
        let Some(tmdb) = self.tmdb()? else { return Ok(None) };
        let language = self.tmdb_language()?;
        let t = now();

        let match_key = format!("tmdb:match:{}:{}", item.source_id, item.uid);
        let cached = self.store().cache_get(&match_key, TMDB_MISS_TTL_SECS.max(TMDB_TTL_SECS), t)?;
        let id = match cached {
            Some(v) if v == "none" => return Ok(None),
            Some(v) => v.parse::<i64>().ok(),
            None => None,
        };
        let id = match id {
            Some(id) => id,
            None => {
                let (title, year) = crate::tmdb::clean_title(&item.name);
                match tmdb.search(media, &title, year.or(item.year))? {
                    Some(id) => {
                        self.store().cache_put(&match_key, &id.to_string(), t)?;
                        id
                    }
                    None => {
                        // Expires sooner than a hit, via the age check below.
                        self.store().cache_put(&match_key, "none", t - (TMDB_TTL_SECS - TMDB_MISS_TTL_SECS))?;
                        return Ok(None);
                    }
                }
            }
        };

        let detail_key = format!("tmdb:{}:{id}:{language}", if media == Media::Movie { "movie" } else { "tv" });
        if let Some(json) = self.store().cache_get(&detail_key, TMDB_TTL_SECS, t)? {
            if let Ok(d) = serde_json::from_str::<TmdbDetail>(&json) {
                return Ok(Some(d));
            }
        }
        let country = language.split('-').nth(1).unwrap_or("TR").to_string();
        match tmdb.detail(media, id, &country) {
            Ok(d) => {
                if let Ok(json) = serde_json::to_string(&d) {
                    self.store().cache_put(&detail_key, &json, t)?;
                }
                Ok(Some(d))
            }
            // Offline: an expired copy beats nothing.
            Err(e) => match self.store().cache_get(&detail_key, i64::MAX / 2, t)? {
                Some(json) => Ok(serde_json::from_str(&json).ok()),
                None => Err(e.into()),
            },
        }
    }

    /// TMDB episode names, overviews and stills for one season of a series.
    pub fn tmdb_season(&self, item_id: i64, season: i32) -> Result<Vec<TmdbEpisode>> {
        let Some(series) = self.tmdb_for(item_id)? else { return Ok(Vec::new()) };
        let Some(tmdb) = self.tmdb()? else { return Ok(Vec::new()) };
        let key = format!("tmdb:season:{}:{season}:{}", series.id, self.tmdb_language()?);
        let t = now();
        if let Some(json) = self.store().cache_get(&key, TMDB_TTL_SECS, t)? {
            if let Ok(list) = serde_json::from_str(&json) {
                return Ok(list);
            }
        }
        let list = tmdb.season(series.id, season)?;
        if let Ok(json) = serde_json::to_string(&list) {
            self.store().cache_put(&key, &json, t)?;
        }
        Ok(list)
    }

    /// Programmes of a catch-up channel that can be replayed, newest first,
    /// within the provider's archive window.
    pub fn archive(&self, item_id: i64) -> Result<Vec<Programme>> {
        let item = self.item(item_id)?;
        let Some(days) = item.catchup_days.filter(|d| *d > 0) else { return Ok(Vec::new()) };
        let t = now();
        let xtream = item.url.starts_with("xtream:live:");
        // Only the full table has past programmes and archive flags. It is
        // large, so it is fetched here, for one channel the user is looking
        // at, never for every row of a list.
        let fetched = self.store().epg_archive_fetched(&item.source_id, item.uid)?;
        if xtream && !fetched.is_some_and(|f| t - f < EPG_TTL_SECS) {
            let source = self.store().source(&item.source_id)?.ok_or_else(|| msg(crate::lang::t("Kaynak bulunamadı", "Source not found")))?;
            if let Ok(table) = self.xtream(&source).and_then(|c| Ok(c.epg_table(item.ext_id.unwrap_or(0))?)) {
                self.store().replace_epg_short(&item.source_id, item.uid, &epg_rows(table), t, true)?;
            }
        }
        let from = t - i64::from(days) * 86_400;
        let rows = if xtream {
            self.store().epg_past(&item.source_id, item.uid, from, t)?
        } else {
            // M3U: the XMLTV guide; the archive covers the whole window.
            let mut past: Vec<EpgRow> = self.guide_programmes(&item, from, t, 5000)?.into_iter().filter(|r| r.stop <= t).collect();
            past.reverse();
            past
        };
        Ok(rows
            .into_iter()
            // Xtream says per programme; M3U archives cover the whole window.
            .filter(|r| !xtream || r.archive)
            .map(|r| Programme { archive: true, ..programme(r) })
            .collect())
    }

    /// Plays [start]..[stop] of a catch-up channel from the provider's archive.
    pub fn catchup(&self, item_id: i64, start: i64, stop: i64) -> Result<PlaybackInfo> {
        let item = self.item(item_id)?;
        let source = self.store().source(&item.source_id)?.ok_or_else(|| msg(t("Kaynak bulunamadı", "Source not found")))?;
        let url = if item.url.starts_with("xtream:live:") {
            let client = self.xtream(&source)?;
            client.timeshift_url(item.ext_id.unwrap_or(0), start, stop, source.timezone.as_deref())
        } else {
            let kind = item.catchup.as_deref().unwrap_or("default");
            crate::catchup::catchup_url(kind, &item.url, item.catchup_source.as_deref(), start, stop, now())
                .ok_or_else(|| msg(t("Bu kanal geçmiş yayın desteklemiyor", "This channel has no catch-up")))?
        };
        Ok(PlaybackInfo {
            url,
            title: item.name.clone(),
            is_live: false,
            user_agent: item.user_agent.clone().or(source.user_agent.clone()),
            referrer: item.referrer.clone(),
            resume_ms: None,
        })
    }

    /// Now / next for one live channel: served from cache, refetched from the
    /// provider when stale. M3U sources get XMLTV in M3.
    pub fn epg(&self, item_id: i64) -> Result<Vec<Programme>> {
        let item = self.item(item_id)?;
        let t = now();
        let portal = item.url.starts_with("stalker:");
        if !item.url.starts_with("xtream:") && !portal {
            return Ok(self.guide_programmes(&item, t, t + 2 * 86_400, 8)?.into_iter().map(programme).collect());
        }
        let (cached, fetched) = self.store().epg_short(&item.source_id, item.uid, t)?;
        let fresh = fetched.map(|f| t - f < EPG_TTL_SECS).unwrap_or(false);
        if fresh || !(item.url.starts_with("xtream:live:") || portal) {
            return Ok(cached.into_iter().map(programme).collect());
        }
        let source = self.store().source(&item.source_id)?.ok_or_else(|| msg(crate::lang::t("Kaynak bulunamadı", "Source not found")))?;
        let stream = item.ext_id.unwrap_or(0);
        let fetched = if portal {
            self.portal(&source).and_then(|p| {
                Ok(p.short_epg(stream)?
                    .into_iter()
                    .map(|e| crate::xtream::ShortEpgEntry { start: e.start, end: e.stop, title: e.title, description: e.description, has_archive: false })
                    .collect())
            })
        } else {
            self.xtream(&source).and_then(|c| Ok(c.short_epg(stream, 6)?))
        };
        let entries = match fetched {
            Ok(e) => e,
            // EPG is decoration: a failing provider keeps the cached copy.
            Err(_) => return Ok(cached.into_iter().map(programme).collect()),
        };
        let mut store = self.store();
        store.replace_epg_short(&item.source_id, item.uid, &epg_rows(entries), t, false)?;
        Ok(store.epg_short(&item.source_id, item.uid, t)?.0.into_iter().map(programme).collect())
    }
}

/// The system's IANA time zone ("Europe/Istanbul"), which portals expect in
/// the box's cookie.
fn local_timezone() -> String {
    iana_time_zone::get_timezone().unwrap_or_else(|_| "Europe/Istanbul".into())
}

/// A guide download as a decompressed byte stream: a local file or a URL.
fn open_guide(url: &str, source: &SourceRow) -> Result<Box<dyn std::io::BufRead>> {
    let url = url.trim();
    let io = |e: std::io::Error| msg(format!("{}: {e}", t("Yayın akışı okunamadı", "Could not read the TV guide")));
    if !(url.starts_with("http://") || url.starts_with("https://")) {
        return crate::xmltv::decompressing(std::fs::File::open(url).map_err(io)?).map_err(io);
    }
    let http = reqwest::blocking::Client::builder()
        // Big guides on slow panels: generous, but not endless.
        .timeout(Duration::from_secs(600))
        .connect_timeout(Duration::from_secs(15))
        .user_agent(source.user_agent.as_deref().unwrap_or(crate::DEFAULT_USER_AGENT))
        .danger_accept_invalid_certs(source.insecure_tls)
        .build()
        .map_err(|e| msg(e.to_string()))?;
    let resp = http.get(url).send().map_err(|e| msg(format!("{}: {}", t("Yayın akışı indirilemedi", "Could not download the TV guide"), strip_query(&e.to_string()))))?;
    if !resp.status().is_success() {
        return Err(msg(format!("{}: HTTP {}", t("Yayın akışı indirilemedi", "Could not download the TV guide"), resp.status().as_u16())));
    }
    crate::xmltv::decompressing(resp).map_err(io)
}

fn encode_guide_status(s: &GuideStatus) -> String {
    match &s.error {
        None => format!("ok|{}|{}|{}|{}", s.programmes, s.matched, s.channels, s.at),
        Some(e) => format!("err|{}|{}", s.at, e.replace('|', "/")),
    }
}

fn decode_guide_status(s: &str) -> Option<GuideStatus> {
    let parts: Vec<&str> = s.splitn(5, '|').collect();
    match parts.as_slice() {
        ["ok", p, m, c, at] => Some(GuideStatus {
            ok: true,
            programmes: p.parse().ok()?,
            matched: m.parse().ok()?,
            channels: c.parse().ok()?,
            error: None,
            at: at.parse().ok()?,
        }),
        ["err", at, rest @ ..] => Some(GuideStatus {
            ok: false,
            programmes: 0,
            matched: 0,
            channels: 0,
            error: Some(rest.join("|")),
            at: at.parse().ok()?,
        }),
        _ => None,
    }
}

/// Development and tests only: points TMDB at tools/mock-iptv.
fn tmdb_base() -> Option<String> {
    std::env::var("KP_TMDB_BASE").ok().filter(|b| !b.is_empty())
}

fn epg_rows(entries: Vec<crate::xtream::ShortEpgEntry>) -> Vec<EpgRow> {
    entries
        .into_iter()
        .map(|e| EpgRow { start: e.start, stop: e.end, title: e.title, description: e.description, archive: e.has_archive })
        .collect()
}

fn programme(e: EpgRow) -> Programme {
    Programme { start: e.start, stop: e.stop, title: e.title, description: e.description, archive: e.archive }
}

fn default_name(url: &str) -> String {
    let host = url
        .trim()
        .trim_start_matches("http://")
        .trim_start_matches("https://")
        .split(['/', ':', '?'])
        .next()
        .unwrap_or("");
    if host.is_empty() { "Kaynak".to_string() } else { host.to_string() }
}

/// What [Core::check_source] found.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct SourceHealth {
    pub ok: bool,
    pub latency_ms: u32,
    pub error: Option<String>,
    /// The provider's word for the account ("Active", "Banned", ...).
    pub status: Option<String>,
    pub expires_at: Option<i64>,
    pub max_connections: Option<i64>,
    pub active_connections: Option<i64>,
}

/// Reaches the playlist without downloading it: the response headers of a
/// one-byte range (servers that ignore ranges are dropped after headers).
fn probe_playlist(source: &SourceRow) -> Result<()> {
    let url = source.url.trim();
    if !(url.starts_with("http://") || url.starts_with("https://")) {
        return std::fs::metadata(url)
            .map(|_| ())
            .map_err(|e| msg(format!("{}: {e}", t("Dosya okunamadı", "Could not read the file"))));
    }
    let http = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(15))
        .connect_timeout(Duration::from_secs(10))
        .user_agent(source.user_agent.as_deref().unwrap_or(crate::DEFAULT_USER_AGENT))
        .danger_accept_invalid_certs(source.insecure_tls)
        .build()
        .map_err(|e| msg(e.to_string()))?;
    let resp = http
        .get(url)
        .header(reqwest::header::RANGE, "bytes=0-0")
        .send()
        .map_err(|e| msg(format!("{}: {}", t("Sunucuya ulaşılamadı", "The server did not answer"), strip_query(&e.to_string()))))?;
    if !resp.status().is_success() {
        return Err(msg(format!("HTTP {}", resp.status().as_u16())));
    }
    Ok(())
}

/// M3U from a URL or a local file. 300 MB cap: AbiPlayer's 20 MB limit
/// rejected many real 100k-entry lists.
fn fetch_playlist(source: &SourceRow) -> Result<String> {
    const MAX: u64 = 300 * 1024 * 1024;
    let url = source.url.trim();
    if !(url.starts_with("http://") || url.starts_with("https://")) {
        let bytes = std::fs::read(url).map_err(|e| msg(format!("{}: {e}", t("Dosya okunamadı", "Could not read the file"))))?;
        return Ok(String::from_utf8_lossy(&bytes).into_owned());
    }
    let http = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(120))
        .connect_timeout(Duration::from_secs(10))
        .user_agent(source.user_agent.as_deref().unwrap_or(crate::DEFAULT_USER_AGENT))
        .danger_accept_invalid_certs(source.insecure_tls)
        .build()
        .map_err(|e| msg(e.to_string()))?;
    let resp = http.get(url).send().map_err(|e| msg(format!("{}: {}", t("Liste indirilemedi", "Could not download the playlist"), strip_query(&e.to_string()))))?;
    if !resp.status().is_success() {
        return Err(msg(format!("{}: HTTP {}", t("Liste indirilemedi", "Could not download the playlist"), resp.status().as_u16())));
    }
    if resp.content_length().unwrap_or(0) > MAX {
        return Err(msg(t("Liste çok büyük (en fazla 300 MB)", "The playlist is too large (300 MB at most)")));
    }
    let bytes = resp.bytes().map_err(|e| msg(format!("{}: {}", t("Liste indirilemedi", "Could not download the playlist"), strip_query(&e.to_string()))))?;
    Ok(String::from_utf8_lossy(&bytes).into_owned())
}

/// M3U URLs often carry credentials in the query string.
fn strip_query(message: &str) -> String {
    message
        .split_whitespace()
        .map(|w| if w.contains("://") { w.split('?').next().unwrap_or(w).to_string() } else { w.to_string() })
        .collect::<Vec<_>>()
        .join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::secret::MemorySecrets;

    #[test]
    fn checking_a_file_source_finds_the_file_or_not() {
        let dir = tempfile::tempdir().unwrap();
        let list = dir.path().join("list.m3u");
        std::fs::write(&list, "#EXTM3U\n#EXTINF:-1,TRT 1\nhttp://s/1.ts\n").unwrap();
        let core = Core::open_in_memory(Box::new(MemorySecrets::default())).unwrap();
        let (source, _) = core
            .add_source(
                NewSource { kind: SourceKind::M3u, name: "Liste".into(), url: list.display().to_string(), username: None, password: None, epg_url: None, user_agent: None, insecure_tls: false },
                &|_| {},
            )
            .unwrap();
        assert!(core.check_source(&source.id).unwrap().ok);
        std::fs::remove_file(&list).unwrap();
        let h = core.check_source(&source.id).unwrap();
        assert!(!h.ok && h.error.is_some(), "{h:?}");
    }

    #[test]
    fn m3u_file_source_end_to_end() {
        let dir = tempfile::tempdir().unwrap();
        let list = dir.path().join("list.m3u");
        std::fs::write(&list, "#EXTM3U\n#EXTINF:-1 group-title=\"Ulusal\",TRT 1\nhttp://s/1.ts\n#EXTINF:-1 group-title=\"Filmler\",Film\nhttp://s/f.mp4\n").unwrap();
        let core = Core::open_in_memory(Box::new(MemorySecrets::default())).unwrap();
        let stages = std::cell::RefCell::new(Vec::new());
        let (source, summary) = core
            .add_source(
                NewSource {
                    kind: SourceKind::M3u,
                    name: String::new(),
                    url: list.to_string_lossy().into_owned(),
                    username: None,
                    password: None,
                    epg_url: None,
                    user_agent: None,
                    insecure_tls: false,
                },
                &|s| stages.borrow_mut().push(s),
            )
            .unwrap();
        assert_eq!(summary, SyncSummary { live: 1, movies: 1, series: 0 });
        assert!(stages.borrow().contains(&SyncStage::Saving));

        let live = core.page(&source.id, ContentKind::Live, None, None, 10).unwrap();
        let play = core.playback(live[0].id, None).unwrap();
        assert_eq!((play.url.as_str(), play.is_live), ("http://s/1.ts", true));
        assert_eq!(core.recent(&source.id, ContentKind::Live, 5).unwrap().len(), 1);

        core.delete_source(&source.id).unwrap();
        assert!(core.sources().unwrap().is_empty());
    }

    #[test]
    fn failed_first_sync_leaves_nothing_behind() {
        let core = Core::open_in_memory(Box::new(MemorySecrets::default())).unwrap();
        let err = core
            .add_source(
                NewSource {
                    kind: SourceKind::M3u,
                    name: "Yok".into(),
                    url: "C:/does/not/exist.m3u".into(),
                    username: None,
                    password: None,
                    epg_url: None,
                    user_agent: None,
                    insecure_tls: false,
                },
                &|_| {},
            )
            .unwrap_err();
        assert!(err.to_string().contains("Dosya okunamadı"));
        assert!(core.sources().unwrap().is_empty());
    }

    #[test]
    fn query_strings_are_stripped_from_errors() {
        assert_eq!(
            strip_query("error sending request for url (http://h/get.php?username=u&password=p)"),
            "error sending request for url (http://h/get.php"
        );
    }
}
