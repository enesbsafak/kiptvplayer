//! The data core's public face: everything the UI asks for goes through here.
//!
//! Calls are synchronous; the bridge runs them on its worker pool, never on
//! the UI thread. Network work happens in `add_source` / `sync` / detail
//! fetches; every list call reads SQLite only, so screens paint instantly.

use std::path::Path;
use std::sync::Mutex;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use serde_json::Value;

use crate::catalog::{Catalog, ContentKind, XtreamLists};
use crate::secret::{password_key, SecretStore};
use crate::tmdb::{Media, Tmdb, TmdbDetail, TmdbEpisode, TmdbError};
use crate::store::{CategoryRow, ChannelRow, EpgRow, ItemRow, ProgressRow, SourceRow, Store, StoreError};
use crate::xtream::{as_array, as_i64, as_string, XtreamClient, XtreamError};

#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error("{0}")]
    Xtream(#[from] XtreamError),
    #[error("veritabanı hatası: {0}")]
    Store(#[from] StoreError),
    #[error("{0}")]
    Tmdb(#[from] TmdbError),
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
}

pub fn now() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
}

impl Core {
    pub fn open(db_path: impl AsRef<Path>, secrets: Box<dyn SecretStore>) -> Result<Self> {
        Ok(Core { store: Mutex::new(Store::open(db_path)?), secrets })
    }

    pub fn open_in_memory(secrets: Box<dyn SecretStore>) -> Result<Self> {
        Ok(Core { store: Mutex::new(Store::open_in_memory()?), secrets })
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
            return Err(msg("Adres boş olamaz"));
        }
        let id = format!("s{:x}", xxhash_rust::xxh3::xxh3_64(format!("{}|{}|{}", new.url, new.username.as_deref().unwrap_or(""), now()).as_bytes()));
        let row = SourceRow {
            id: id.clone(),
            kind: match new.kind {
                SourceKind::Xtream => "xtream".into(),
                SourceKind::M3u => "m3u".into(),
            },
            name: if name.is_empty() { default_name(&new.url) } else { name.to_string() },
            url: match new.kind {
                SourceKind::Xtream => crate::xtream::normalize_base(&new.url),
                SourceKind::M3u => new.url.trim().to_string(),
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
            let user = row.username.clone().ok_or_else(|| msg("Kullanıcı adı gerekli"))?;
            on_stage(SyncStage::Connecting);
            let client = XtreamClient::new(&row.url, &user, &password, row.user_agent.as_deref(), row.insecure_tls)?;
            client.account()?;
            self.secrets.set(&password_key(&id), &password).map_err(|e| msg(format!("Şifre kaydedilemedi: {e}")))?;
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
        Ok(())
    }

    /// Downloads the source's catalog and swaps it in atomically. Readers
    /// keep seeing the old catalog until the new one is fully written.
    pub fn sync(&self, source_id: &str, on_stage: &dyn Fn(SyncStage)) -> Result<SyncSummary> {
        let source = self.store().source(source_id)?.ok_or_else(|| msg("Kaynak bulunamadı"))?;
        let result = self.download_catalog(&source, on_stage);
        match result {
            Ok((catalog, account)) => {
                on_stage(SyncStage::Saving);
                let mut store = self.store();
                store.replace_catalog(source_id, &catalog, now())?;
                if let Some(a) = account {
                    store.set_source_status(source_id, None, a.expires_at, a.max_connections, a.server_timezone.as_deref())?;
                }
                Ok(SyncSummary {
                    live: store.count_by_kind(source_id, ContentKind::Live)?,
                    movies: store.count_by_kind(source_id, ContentKind::Movie)?,
                    series: store.count_by_kind(source_id, ContentKind::Series)?,
                })
            }
            Err(e) => {
                self.store().set_source_status(source_id, Some(&e.to_string()), None, None, None)?;
                Err(e)
            }
        }
    }

    fn download_catalog(&self, source: &SourceRow, on_stage: &dyn Fn(SyncStage)) -> Result<(Catalog, Option<crate::xtream::AccountInfo>)> {
        on_stage(SyncStage::Connecting);
        if source.kind == "xtream" {
            let client = self.xtream(source)?;
            let account = client.account()?;
            let mut lists = Vec::new();
            for (kind, label) in [
                (ContentKind::Live, "Canlı kanallar"),
                (ContentKind::Movie, "Filmler"),
                (ContentKind::Series, "Diziler"),
            ] {
                on_stage(SyncStage::Downloading { what: label.into() });
                lists.push(XtreamLists { kind, categories: client.categories(kind)?, items: client.items(kind)? });
            }
            Ok((Catalog::from_xtream(lists), Some(account)))
        } else {
            on_stage(SyncStage::Downloading { what: "Oynatma listesi".into() });
            let text = fetch_playlist(source)?;
            let catalog = Catalog::from_m3u(crate::m3u::parse(&text));
            if catalog.channels.is_empty() {
                return Err(msg("Listede oynatılabilir kanal bulunamadı"));
            }
            Ok((catalog, None))
        }
    }

    fn xtream(&self, source: &SourceRow) -> Result<XtreamClient> {
        let password = self
            .secrets
            .get(&password_key(&source.id))
            .ok_or_else(|| msg("Bu kaynağın şifresi bulunamadı; kaynağı yeniden ekleyin"))?;
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

    pub fn continue_watching(&self, source_id: &str, limit: u32) -> Result<Vec<ProgressRow>> {
        Ok(self.store().continue_watching(source_id, limit)?)
    }

    pub fn item(&self, id: i64) -> Result<ItemRow> {
        self.store().item(id)?.ok_or_else(|| msg("İçerik bulunamadı"))
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
        let source = self.store().source(&item.source_id)?.ok_or_else(|| msg("Kaynak bulunamadı"))?;
        let resume_key = episode.as_ref().map(|e| e.0).unwrap_or(item.uid);
        let resume_ms = self.store().progress(&item.source_id, resume_key)?.map(|p| p.position_ms).filter(|p| *p > 5_000);

        let url = if let Some(rest) = item.url.strip_prefix("xtream:") {
            let client = self.xtream(&source)?;
            let id = item.ext_id.ok_or_else(|| msg("Geçersiz içerik"))?;
            match (rest.split(':').next(), &episode) {
                (_, Some((episode_id, container))) => client.episode_url(*episode_id, container),
                (Some("live"), None) => client.live_url(id, "ts"),
                (Some("movie"), None) => client.movie_url(id, item.container.as_deref().unwrap_or("mp4")),
                _ => return Err(msg("Diziler için bölüm seçin")),
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
        let source = self.store().source(&item.source_id)?.ok_or_else(|| msg("Kaynak bulunamadı"))?;
        let client = self.xtream(&source)?;
        let ext = item.ext_id.ok_or_else(|| msg("Geçersiz içerik"))?;
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

    fn tmdb_language(&self) -> Result<String> {
        Ok(self.store().setting("tmdb_language")?.filter(|l| !l.is_empty()).unwrap_or_else(|| "tr-TR".into()))
    }

    /// Saves (after checking it with TMDB) or, with None, forgets the key.
    /// v3 API keys and v4 read access tokens both work.
    pub fn set_tmdb_key(&self, key: Option<&str>) -> Result<()> {
        match key.map(str::trim).filter(|k| !k.is_empty()) {
            None => self.secrets.delete(TMDB_KEY),
            Some(k) => {
                Tmdb::new(k, &self.tmdb_language()?, tmdb_base().as_deref())?.validate()?;
                self.secrets.set(TMDB_KEY, k).map_err(|e| msg(format!("Anahtar kaydedilemedi: {e}")))?;
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
            let source = self.store().source(&item.source_id)?.ok_or_else(|| msg("Kaynak bulunamadı"))?;
            if let Ok(table) = self.xtream(&source).and_then(|c| Ok(c.epg_table(item.ext_id.unwrap_or(0))?)) {
                self.store().replace_epg_short(&item.source_id, item.uid, &epg_rows(table), t, true)?;
            }
        }
        let rows = self.store().epg_past(&item.source_id, item.uid, t - i64::from(days) * 86_400, t)?;
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
        let source = self.store().source(&item.source_id)?.ok_or_else(|| msg("Kaynak bulunamadı"))?;
        let url = if item.url.starts_with("xtream:live:") {
            let client = self.xtream(&source)?;
            client.timeshift_url(item.ext_id.unwrap_or(0), start, stop, source.timezone.as_deref())
        } else {
            let kind = item.catchup.as_deref().unwrap_or("default");
            crate::catchup::catchup_url(kind, &item.url, item.catchup_source.as_deref(), start, stop, now())
                .ok_or_else(|| msg("Bu kanal geçmiş yayın desteklemiyor"))?
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
        let (cached, fetched) = self.store().epg_short(&item.source_id, item.uid, t)?;
        let fresh = fetched.map(|f| t - f < EPG_TTL_SECS).unwrap_or(false);
        if fresh || !item.url.starts_with("xtream:live:") {
            return Ok(cached.into_iter().map(programme).collect());
        }
        let source = self.store().source(&item.source_id)?.ok_or_else(|| msg("Kaynak bulunamadı"))?;
        let entries = match self.xtream(&source).and_then(|c| Ok(c.short_epg(item.ext_id.unwrap_or(0), 6)?)) {
            Ok(e) => e,
            // EPG is decoration: a failing provider keeps the cached copy.
            Err(_) => return Ok(cached.into_iter().map(programme).collect()),
        };
        let mut store = self.store();
        store.replace_epg_short(&item.source_id, item.uid, &epg_rows(entries), t, false)?;
        Ok(store.epg_short(&item.source_id, item.uid, t)?.0.into_iter().map(programme).collect())
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

/// M3U from a URL or a local file. 300 MB cap: AbiPlayer's 20 MB limit
/// rejected many real 100k-entry lists.
fn fetch_playlist(source: &SourceRow) -> Result<String> {
    const MAX: u64 = 300 * 1024 * 1024;
    let url = source.url.trim();
    if !(url.starts_with("http://") || url.starts_with("https://")) {
        let bytes = std::fs::read(url).map_err(|e| msg(format!("Dosya okunamadı: {e}")))?;
        return Ok(String::from_utf8_lossy(&bytes).into_owned());
    }
    let http = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(120))
        .connect_timeout(Duration::from_secs(10))
        .user_agent(source.user_agent.as_deref().unwrap_or(crate::DEFAULT_USER_AGENT))
        .danger_accept_invalid_certs(source.insecure_tls)
        .build()
        .map_err(|e| msg(e.to_string()))?;
    let resp = http.get(url).send().map_err(|e| msg(format!("Liste indirilemedi: {}", strip_query(&e.to_string()))))?;
    if !resp.status().is_success() {
        return Err(msg(format!("Liste indirilemedi: HTTP {}", resp.status().as_u16())));
    }
    if resp.content_length().unwrap_or(0) > MAX {
        return Err(msg("Liste çok büyük (en fazla 300 MB)"));
    }
    let bytes = resp.bytes().map_err(|e| msg(format!("Liste indirilemedi: {}", strip_query(&e.to_string()))))?;
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
