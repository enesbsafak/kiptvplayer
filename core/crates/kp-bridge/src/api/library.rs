//! Dart-facing API. Plain data types only; every call runs on the bridge's
//! worker pool, so blocking SQLite and network work never touches the UI
//! thread.

use std::path::PathBuf;
use std::sync::OnceLock;

use anyhow::{anyhow, Result};
use flutter_rust_bridge::frb;
use kp_core::core::{Core, NewSource, SourceKind, SyncStage};
use kp_core::secret::{MemorySecrets, OsKeyring};
use kp_core::store::{CategoryRow, ChannelRow, SourceRow};
use kp_core::ContentKind;

use crate::frb_generated::StreamSink;

static CORE: OnceLock<Core> = OnceLock::new();

pub(crate) fn core() -> Result<&'static Core> {
    CORE.get().ok_or_else(|| anyhow!(kp_core::lang::t("kütüphane başlatılmadı", "the library is not open")))
}

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// Opens (or creates) the library under [data_dir]. Safe to call twice.
/// [ephemeral_secrets] keeps passwords and keys in memory instead of the OS
/// keyring: for automated runs, which must never touch the user's
/// credentials (or leave entries behind).
pub fn open_library(data_dir: String, ephemeral_secrets: bool) -> Result<()> {
    if CORE.get().is_some() {
        return Ok(());
    }
    let dir = PathBuf::from(data_dir);
    std::fs::create_dir_all(&dir)?;
    let secrets: Box<dyn kp_core::secret::SecretStore> =
        if ephemeral_secrets { Box::new(MemorySecrets::default()) } else { Box::new(OsKeyring) };
    let core = Core::open(dir.join("library.sqlite"), secrets)?;
    let _ = CORE.set(core);
    Ok(())
}

// ---- types --------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Live,
    Movie,
    Series,
}

impl From<Kind> for ContentKind {
    fn from(k: Kind) -> Self {
        match k {
            Kind::Live => ContentKind::Live,
            Kind::Movie => ContentKind::Movie,
            Kind::Series => ContentKind::Series,
        }
    }
}

impl From<ContentKind> for Kind {
    fn from(k: ContentKind) -> Self {
        match k {
            ContentKind::Live => Kind::Live,
            ContentKind::Movie => Kind::Movie,
            ContentKind::Series => Kind::Series,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SourceType {
    Xtream,
    M3u,
    /// Stalker / Ministra portal (MAC address).
    Stalker,
}

#[derive(Debug, Clone)]
pub struct SourceInfo {
    pub id: String,
    pub kind: SourceType,
    pub name: String,
    pub url: String,
    pub username: Option<String>,
    pub synced_at: Option<i64>,
    pub last_error: Option<String>,
    pub expires_at: Option<i64>,
    pub max_connections: Option<i64>,
    pub live_count: u64,
    pub movie_count: u64,
    pub series_count: u64,
    /// XMLTV guide URL (M3U), from the playlist header or the user.
    pub epg_url: Option<String>,
    pub guide: Option<GuideInfo>,
}

/// "Kaynağı kontrol et": the provider's answer time and account state.
#[derive(Debug, Clone)]
pub struct SourceHealth {
    pub ok: bool,
    pub latency_ms: u32,
    pub error: Option<String>,
    pub status: Option<String>,
    pub expires_at: Option<i64>,
    pub max_connections: Option<i64>,
    pub active_connections: Option<i64>,
}

/// One light request to the source, timed; never opens a stream.
pub fn check_source(source_id: String) -> Result<SourceHealth> {
    let h = core()?.check_source(&source_id)?;
    Ok(SourceHealth {
        ok: h.ok,
        latency_ms: h.latency_ms,
        error: h.error,
        status: h.status,
        expires_at: h.expires_at,
        max_connections: h.max_connections,
        active_connections: h.active_connections,
    })
}

/// The last XMLTV guide download of an M3U source.
#[derive(Debug, Clone)]
pub struct GuideInfo {
    pub ok: bool,
    pub programmes: u64,
    pub matched: u64,
    pub channels: u64,
    pub error: Option<String>,
    pub at: i64,
}

#[derive(Debug, Clone)]
pub struct NewSourceInput {
    pub kind: SourceType,
    pub name: String,
    pub url: String,
    pub username: Option<String>,
    pub password: Option<String>,
    pub user_agent: Option<String>,
    pub insecure_tls: bool,
    /// M3U only: an XMLTV guide URL, when the playlist announces none.
    pub epg_url: Option<String>,
}

#[derive(Debug, Clone)]
pub enum SyncEvent {
    Connecting,
    Downloading { what: String },
    Saving,
    Done { source: SourceInfo },
    Failed { message: String },
}

#[derive(Debug, Clone)]
pub struct Category {
    pub uid: i64,
    pub name: String,
    pub adult: bool,
    pub count: u32,
}

#[derive(Debug, Clone)]
pub struct Item {
    pub id: i64,
    pub uid: i64,
    pub name: String,
    pub logo: Option<String>,
    pub chno: Option<u32>,
    pub adult: bool,
    pub sort: u32,
    pub rating: Option<f32>,
    pub year: Option<i32>,
    pub has_catchup: bool,
}

#[derive(Debug, Clone)]
pub struct Playback {
    pub url: String,
    pub title: String,
    pub is_live: bool,
    pub user_agent: Option<String>,
    pub referrer: Option<String>,
    pub resume_ms: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct Programme {
    pub start: i64,
    pub stop: i64,
    pub title: String,
    pub description: String,
    /// Can be played back from the provider's archive (catch-up).
    pub archive: bool,
}

#[derive(Debug, Clone)]
pub struct EpisodeInfo {
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

#[derive(Debug, Clone)]
pub struct ItemDetail {
    pub id: i64,
    pub kind: Kind,
    pub name: String,
    pub poster: Option<String>,
    pub rating: Option<f32>,
    pub year: Option<i32>,
    pub plot: Option<String>,
    pub genre: Option<String>,
    pub cast: Option<String>,
    pub director: Option<String>,
    pub duration_secs: Option<i64>,
    pub backdrop: Option<String>,
    /// The provider's trailer: a YouTube id or URL.
    pub trailer: Option<String>,
    pub episodes: Vec<EpisodeInfo>,
    pub is_favorite: bool,
    pub progress_ms: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct ContinueItem {
    pub item: Item,
    pub kind: Kind,
    pub episode_id: Option<i64>,
    pub title: String,
    pub position_ms: i64,
    pub duration_ms: i64,
}

fn item(r: ChannelRow) -> Item {
    Item {
        id: r.id,
        uid: r.uid,
        name: r.name,
        logo: r.logo,
        chno: r.chno,
        adult: r.adult,
        sort: r.sort,
        rating: r.rating,
        year: r.year,
        has_catchup: r.has_catchup,
    }
}

fn items(rows: Vec<ChannelRow>) -> Vec<Item> {
    rows.into_iter().map(item).collect()
}

fn source_info(core: &Core, s: SourceRow) -> Result<SourceInfo> {
    let guide = core.guide_status(&s.id)?.map(|g| GuideInfo {
        ok: g.ok,
        programmes: g.programmes,
        matched: g.matched,
        channels: g.channels,
        error: g.error,
        at: g.at,
    });
    Ok(SourceInfo {
        epg_url: s.epg_url.clone(),
        guide,
        live_count: core.count(&s.id, ContentKind::Live)?,
        movie_count: core.count(&s.id, ContentKind::Movie)?,
        series_count: core.count(&s.id, ContentKind::Series)?,
        kind: match s.kind.as_str() {
            "xtream" => SourceType::Xtream,
            "stalker" => SourceType::Stalker,
            _ => SourceType::M3u,
        },
        id: s.id,
        name: s.name,
        url: s.url,
        username: s.username,
        synced_at: s.synced_at,
        last_error: s.last_error,
        expires_at: s.expires_at,
        max_connections: s.max_connections,
    })
}

fn stage_event(stage: SyncStage) -> SyncEvent {
    match stage {
        SyncStage::Connecting => SyncEvent::Connecting,
        SyncStage::Downloading { what } => SyncEvent::Downloading { what },
        SyncStage::Saving => SyncEvent::Saving,
    }
}

// ---- sources --------------------------------------------------------------

pub fn list_sources() -> Result<Vec<SourceInfo>> {
    let core = core()?;
    core.sources()?.into_iter().map(|s| source_info(core, s)).collect()
}

/// Validates, stores and syncs a new source, streaming progress. The stream
/// always ends with `Done` or `Failed`.
pub fn add_source(input: NewSourceInput, sink: StreamSink<SyncEvent>) -> Result<()> {
    let core = core()?;
    let new = NewSource {
        kind: match input.kind {
            SourceType::Xtream => SourceKind::Xtream,
            SourceType::M3u => SourceKind::M3u,
            SourceType::Stalker => SourceKind::Stalker,
        },
        name: input.name,
        url: input.url,
        username: input.username,
        password: input.password,
        epg_url: input.epg_url.filter(|u| !u.trim().is_empty()),
        user_agent: input.user_agent,
        insecure_tls: input.insecure_tls,
    };
    let result = core.add_source(new, &|s| {
        let _ = sink.add(stage_event(s));
    });
    let _ = match result {
        Ok((source, _)) => sink.add(SyncEvent::Done { source: source_info(core, source)? }),
        Err(e) => sink.add(SyncEvent::Failed { message: e.to_string() }),
    };
    Ok(())
}

/// Downloads the source's XMLTV guide again. Errors are also kept in the
/// returned source's `guide`.
pub fn refresh_guide(source_id: String) -> Result<SourceInfo> {
    let core = core()?;
    let _ = core.refresh_guide(&source_id);
    let s = core.sources()?.into_iter().find(|s| s.id == source_id).ok_or_else(|| anyhow!("Kaynak bulunamadı"))?;
    source_info(core, s)
}

pub fn sync_source(source_id: String, sink: StreamSink<SyncEvent>) -> Result<()> {
    let core = core()?;
    let result = core.sync(&source_id, &|s| {
        let _ = sink.add(stage_event(s));
    });
    let _ = match result {
        Ok(_) => match core.sources()?.into_iter().find(|s| s.id == source_id) {
            Some(s) => sink.add(SyncEvent::Done { source: source_info(core, s)? }),
            None => sink.add(SyncEvent::Failed { message: kp_core::lang::t("Kaynak bulunamadı", "Source not found").into() }),
        },
        Err(e) => sink.add(SyncEvent::Failed { message: e.to_string() }),
    };
    Ok(())
}

pub fn remove_source(source_id: String) -> Result<()> {
    Ok(core()?.delete_source(&source_id)?)
}

// ---- browsing ---------------------------------------------------------------

pub fn categories(source_id: String, kind: Kind) -> Result<Vec<Category>> {
    Ok(core()?
        .categories(&source_id, kind.into())?
        .into_iter()
        .map(|c: CategoryRow| Category { uid: c.uid, name: c.name, adult: c.adult, count: c.count })
        .collect())
}

fn cats(rows: Vec<CategoryRow>) -> Vec<Category> {
    rows.into_iter().map(|c| Category { uid: c.uid, name: c.name, adult: c.adult, count: c.count }).collect()
}

// ---- the user's edits: hidden, renamed, ordered, custom groups --------

pub fn hide_channel(item_id: i64, hidden: bool) -> Result<()> {
    Ok(core()?.hide_channel(item_id, hidden)?)
}

/// None (or blank) gives the channel its provider name back.
pub fn rename_channel(item_id: i64, name: Option<String>) -> Result<()> {
    Ok(core()?.rename_channel(item_id, name.as_deref())?)
}

pub fn hide_category(source_id: String, uid: i64, hidden: bool) -> Result<()> {
    Ok(core()?.hide_category(&source_id, uid, hidden)?)
}

pub fn rename_category(source_id: String, uid: i64, name: Option<String>) -> Result<()> {
    Ok(core()?.rename_category(&source_id, uid, name.as_deref())?)
}

pub fn move_category(source_id: String, kind: Kind, uid: i64, delta: i32) -> Result<()> {
    Ok(core()?.move_category(&source_id, kind.into(), uid, delta)?)
}

/// What a backup holds or brought back.
#[derive(Debug, Clone)]
pub struct BackupCounts {
    pub sources: u32,
    pub favorites: u32,
    pub groups: u32,
    pub edits: u32,
}

/// The result of a restore: counts, and sources to sync (no catalog yet).
#[derive(Debug, Clone)]
pub struct RestoreResult {
    pub counts: BackupCounts,
    pub to_sync: Vec<String>,
}

fn counts(c: kp_core::store::ImportCounts) -> BackupCounts {
    BackupCounts { sources: c.sources, favorites: c.favorites, groups: c.groups, edits: c.edits }
}

/// Writes an encrypted backup (password: 8+ characters) to [path].
pub fn export_backup(path: String, password: String) -> Result<BackupCounts> {
    Ok(counts(core()?.export_backup(std::path::Path::new(&path), &password)?))
}

pub fn import_backup(path: String, password: String) -> Result<RestoreResult> {
    let (c, to_sync) = core()?.import_backup(std::path::Path::new(&path), &password)?;
    Ok(RestoreResult { counts: counts(c), to_sync })
}

/// A live channel's guide corrections (the mapping editor).
#[derive(Debug, Clone)]
pub struct EpgSettings {
    /// The source has an XMLTV guide to pick a channel from.
    pub has_guide: bool,
    /// The automatic match.
    pub mapped: Option<GuideEntry>,
    /// The user's pick: None automatic, "" none, else a guide id.
    pub forced: Option<String>,
    pub forced_label: Option<String>,
    pub shift_minutes: i32,
}

/// A channel of the XMLTV guide.
#[derive(Debug, Clone)]
pub struct GuideEntry {
    pub id: String,
    pub label: String,
}

pub fn epg_settings(item_id: i64) -> Result<EpgSettings> {
    let s = core()?.epg_settings(item_id)?;
    Ok(EpgSettings {
        has_guide: s.has_guide,
        mapped: s.mapped.map(|(id, label)| GuideEntry { id, label }),
        forced: s.forced,
        forced_label: s.forced_label,
        shift_minutes: s.shift_min,
    })
}

/// [forced]: None automatic, Some("") no guide, Some(id) that guide channel.
pub fn set_epg_settings(item_id: i64, forced: Option<String>, shift_minutes: i32) -> Result<()> {
    Ok(core()?.set_epg_settings(item_id, forced.as_deref(), shift_minutes)?)
}

pub fn find_guide_channels(source_id: String, query: String) -> Result<Vec<GuideEntry>> {
    Ok(core()?
        .find_guide_channels(&source_id, &query, 40)?
        .into_iter()
        .map(|(id, label)| GuideEntry { id, label })
        .collect())
}

/// What the user hid, to bring back.
#[derive(Debug, Clone)]
pub struct HiddenItems {
    pub categories: Vec<Category>,
    pub channels: Vec<Item>,
}

pub fn hidden_items(source_id: String) -> Result<HiddenItems> {
    let (c, ch) = core()?.hidden(&source_id)?;
    Ok(HiddenItems { categories: cats(c), channels: items(ch) })
}

/// The provider's name of a renamed channel (or category).
pub fn original_name(source_id: String, uid: i64, category: bool) -> Result<Option<String>> {
    Ok(core()?.original_name(&source_id, uid, category)?)
}

/// Custom groups; `uid` is the group id.
pub fn user_groups(source_id: String, kind: Kind) -> Result<Vec<Category>> {
    Ok(cats(core()?.user_groups(&source_id, kind.into())?))
}

pub fn create_group(source_id: String, kind: Kind, name: String) -> Result<i64> {
    Ok(core()?.create_group(&source_id, kind.into(), &name)?)
}

pub fn rename_group(group_id: i64, name: String) -> Result<()> {
    Ok(core()?.rename_group(group_id, &name)?)
}

pub fn delete_group(group_id: i64) -> Result<()> {
    Ok(core()?.delete_group(group_id)?)
}

pub fn move_group(group_id: i64, delta: i32) -> Result<()> {
    Ok(core()?.move_group(group_id, delta)?)
}

pub fn add_to_group(group_id: i64, item_id: i64) -> Result<()> {
    Ok(core()?.add_to_group(group_id, item_id)?)
}

pub fn remove_from_group(group_id: i64, item_id: i64) -> Result<()> {
    Ok(core()?.remove_from_group(group_id, item_id)?)
}

pub fn move_in_group(group_id: i64, item_id: i64, delta: i32) -> Result<()> {
    Ok(core()?.move_in_group(group_id, item_id, delta)?)
}

pub fn group_items(group_id: i64) -> Result<Vec<Item>> {
    Ok(items(core()?.group_items(group_id)?))
}

pub fn items_page(source_id: String, kind: Kind, category_uid: Option<i64>, after_sort: Option<u32>, limit: u32) -> Result<Vec<Item>> {
    Ok(items(core()?.page(&source_id, kind.into(), category_uid, after_sort, limit)?))
}

pub fn search(query: String, kind: Option<Kind>, limit: u32) -> Result<Vec<Item>> {
    Ok(items(core()?.search(&query, kind.map(Into::into), limit)?))
}

pub fn recently_added(source_id: String, kind: Kind, limit: u32) -> Result<Vec<Item>> {
    Ok(items(core()?.recently_added(&source_id, kind.into(), limit)?))
}

/// Backup streams of a live channel (same tvg-id or name), for failover.
pub fn alternates(item_id: i64) -> Result<Vec<Item>> {
    Ok(items(core()?.alternates(item_id)?))
}

pub fn favorites(source_id: String, kind: Kind) -> Result<Vec<Item>> {
    Ok(items(core()?.favorites(&source_id, kind.into())?))
}

/// A programme the user asked to be reminded of, with its channel.
#[derive(Debug, Clone)]
pub struct Reminder {
    pub item: Item,
    pub start: i64,
    pub stop: i64,
    pub title: String,
}

/// Parental lock state: a PIN exists, and adult content is hidden now.
#[derive(Debug, Clone)]
pub struct Parental {
    pub pin_set: bool,
    pub locked: bool,
}

pub fn parental() -> Result<Parental> {
    let s = core()?.parental()?;
    Ok(Parental { pin_set: s.pin_set, locked: s.locked })
}

/// Sets, changes (with the current PIN) or removes (new = None) the PIN.
pub fn set_parental_pin(current: Option<String>, new: Option<String>) -> Result<Parental> {
    let s = core()?.set_parental_pin(current.as_deref(), new.as_deref())?;
    Ok(Parental { pin_set: s.pin_set, locked: s.locked })
}

/// False on a wrong PIN; an error while too many tries make it wait.
pub fn unlock_adult(pin: String) -> Result<bool> {
    Ok(core()?.unlock_adult(&pin)?)
}

pub fn lock_adult() -> Result<()> {
    Ok(core()?.lock_adult()?)
}

/// How many adult categories the lock hides in this kind.
pub fn locked_categories(source_id: String, kind: Kind) -> Result<u32> {
    Ok(core()?.locked_categories(&source_id, kind.into())?)
}

/// An app preference (stored with the library); None when unset.
pub fn app_setting(key: String) -> Result<Option<String>> {
    Ok(core()?.app_setting(&key)?)
}

/// Stores (or with None, clears) an app preference.
pub fn set_app_setting(key: String, value: Option<String>) -> Result<()> {
    Ok(core()?.set_app_setting(&key, value.as_deref())?)
}

/// Sets or clears a reminder for a programme of a live channel.
pub fn set_reminder(item_id: i64, start: i64, stop: i64, title: String, on: bool) -> Result<()> {
    Ok(core()?.set_reminder(item_id, &kp_core::store::ReminderRow { start, stop, title }, on)?)
}

/// Reminders of programmes not over yet, soonest first.
pub fn reminders(source_id: String) -> Result<Vec<Reminder>> {
    Ok(core()?
        .reminders(&source_id)?
        .into_iter()
        .map(|(c, r)| Reminder { item: item(c), start: r.start, stop: r.stop, title: r.title })
        .collect())
}

pub fn recent(source_id: String, kind: Kind, limit: u32) -> Result<Vec<Item>> {
    Ok(items(core()?.recent(&source_id, kind.into(), limit)?))
}

/// Forgets recently watched channels ([recent]) and/or resume points
/// ([progress]) of a source; favorites stay.
pub fn clear_history(source_id: String, recent: bool, progress: bool) -> Result<()> {
    Ok(core()?.clear_history(&source_id, recent, progress)?)
}

pub fn continue_watching(source_id: String, limit: u32) -> Result<Vec<ContinueItem>> {
    let core = core()?;
    let mut out = Vec::new();
    for p in core.continue_watching(&source_id, limit)? {
        let Some(it) = core.item_by_uid(&source_id, p.item_uid)? else { continue };
        out.push(ContinueItem {
            kind: it.kind.into(),
            item: Item {
                id: it.id,
                uid: it.uid,
                name: it.name,
                logo: it.logo,
                chno: None,
                adult: false,
                sort: 0,
                rating: it.rating,
                year: it.year,
                has_catchup: false,
            },
            episode_id: (p.uid != p.item_uid).then_some(p.uid),
            title: p.title,
            position_ms: p.position_ms,
            duration_ms: p.duration_ms,
        });
    }
    Ok(out)
}

pub fn set_favorite(item_id: i64, on: bool) -> Result<()> {
    Ok(core()?.set_favorite(item_id, on)?)
}

pub fn is_favorite(item_id: i64) -> Result<bool> {
    Ok(core()?.is_favorite(item_id)?)
}

pub fn save_progress(item_id: i64, episode_id: Option<i64>, title: String, position_ms: i64, duration_ms: i64) -> Result<()> {
    Ok(core()?.save_progress(item_id, episode_id, &title, position_ms, duration_ms)?)
}

// ---- preferences --------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct RegionPreference {
    /// False until the user (or first run) picked a value.
    pub chosen: bool,
    pub region: Option<String>,
}

#[derive(Debug, Clone)]
pub struct RegionCount {
    pub region: String,
    pub count: u32,
}

pub fn region_preference() -> Result<RegionPreference> {
    let (chosen, region) = core()?.region_preference()?;
    Ok(RegionPreference { chosen, region })
}

/// Puts [region]'s categories and channels first everywhere; None keeps the
/// provider's order (adult content always goes last).
pub fn set_region_preference(region: Option<String>) -> Result<()> {
    Ok(core()?.set_region_preference(region.as_deref())?)
}

pub fn source_regions(source_id: String) -> Result<Vec<RegionCount>> {
    Ok(core()?
        .regions(&source_id)?
        .into_iter()
        .map(|(region, count)| RegionCount { region, count })
        .collect())
}

// ---- playback, detail, EPG --------------------------------------------------

/// [episode_id] and [container] select a series episode.
pub fn playback(item_id: i64, episode_id: Option<i64>, container: Option<String>) -> Result<Playback> {
    let episode = episode_id.map(|id| (id, container.unwrap_or_else(|| "mp4".into())));
    Ok(to_playback(core()?.playback(item_id, episode)?))
}

/// Plays one past programme of a catch-up channel.
pub fn catchup_playback(item_id: i64, start: i64, stop: i64) -> Result<Playback> {
    Ok(to_playback(core()?.catchup(item_id, start, stop)?))
}

fn to_playback(p: kp_core::core::PlaybackInfo) -> Playback {
    Playback {
        url: p.url,
        title: p.title,
        is_live: p.is_live,
        user_agent: p.user_agent,
        referrer: p.referrer,
        resume_ms: p.resume_ms,
    }
}

pub fn detail(item_id: i64) -> Result<ItemDetail> {
    let d = core()?.detail(item_id)?;
    Ok(ItemDetail {
        id: d.item.id,
        kind: d.item.kind.into(),
        name: d.item.name,
        poster: d.item.logo,
        rating: d.item.rating,
        year: d.item.year,
        plot: d.plot,
        genre: d.genre,
        cast: d.cast,
        director: d.director,
        duration_secs: d.duration_secs,
        backdrop: d.backdrop,
        trailer: d.trailer,
        episodes: d
            .episodes
            .into_iter()
            .map(|e| EpisodeInfo {
                ext_id: e.ext_id,
                season: e.season,
                number: e.number,
                title: e.title,
                plot: e.plot,
                image: e.image,
                duration_secs: e.duration_secs,
                container: e.container,
                progress_ms: e.progress_ms,
            })
            .collect(),
        is_favorite: d.is_favorite,
        progress_ms: d.progress_ms,
    })
}

pub fn epg(item_id: i64) -> Result<Vec<Programme>> {
    Ok(core()?.epg(item_id)?.into_iter().map(to_programme).collect())
}

/// Past programmes that can be replayed, newest first.
pub fn archive(item_id: i64) -> Result<Vec<Programme>> {
    Ok(core()?.archive(item_id)?.into_iter().map(to_programme).collect())
}

fn to_programme(p: kp_core::core::Programme) -> Programme {
    Programme { start: p.start, stop: p.stop, title: p.title, description: p.description, archive: p.archive }
}

// ---- TMDB -----------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct TmdbStatus {
    pub configured: bool,
    pub language: String,
}

#[derive(Debug, Clone)]
pub struct TmdbPerson {
    pub name: String,
    pub role: Option<String>,
    pub photo: Option<String>,
}

#[derive(Debug, Clone)]
pub struct TmdbInfo {
    pub id: i64,
    pub title: String,
    pub original_title: Option<String>,
    pub tagline: Option<String>,
    pub overview: Option<String>,
    pub genres: Vec<String>,
    pub year: Option<i32>,
    pub runtime_min: Option<i32>,
    pub rating: Option<f32>,
    pub vote_count: Option<i64>,
    pub poster: Option<String>,
    pub backdrop: Option<String>,
    pub certification: Option<String>,
    /// YouTube video id.
    pub trailer: Option<String>,
    pub cast: Vec<TmdbPerson>,
    pub makers: Vec<String>,
    pub seasons: i32,
}

#[derive(Debug, Clone)]
pub struct TmdbEpisodeInfo {
    pub season: i32,
    pub number: i32,
    pub name: Option<String>,
    pub overview: Option<String>,
    pub still: Option<String>,
    pub runtime_min: Option<i32>,
    pub air_date: Option<String>,
}

/// One subtitle file found on OpenSubtitles.
#[derive(Debug, Clone)]
pub struct SubtitleResult {
    pub file_id: i64,
    pub language: String,
    pub release: String,
    pub file_name: String,
    pub downloads: i64,
    pub hearing_impaired: bool,
    pub machine: bool,
    pub trusted: bool,
}

/// A downloaded subtitle: its path, and downloads left today if known.
#[derive(Debug, Clone)]
pub struct SubtitleFile {
    pub path: String,
    pub remaining: Option<i64>,
}

pub fn opensubs_configured() -> Result<bool> {
    Ok(core()?.opensubs_configured())
}

/// Checks the key with OpenSubtitles and saves it in the OS keyring; None removes it.
pub fn set_opensubs_key(key: Option<String>) -> Result<()> {
    Ok(core()?.set_opensubs_key(key.as_deref())?)
}

/// Subtitles for a film, or (season, episode) of a series.
pub fn subtitle_search(item_id: i64, season: Option<i32>, episode: Option<i32>) -> Result<Vec<SubtitleResult>> {
    let ep = season.zip(episode);
    Ok(core()?
        .subtitle_search(item_id, ep)?
        .into_iter()
        .map(|r| SubtitleResult {
            file_id: r.file_id,
            language: r.language,
            release: r.release,
            file_name: r.file_name,
            downloads: r.downloads,
            hearing_impaired: r.hearing_impaired,
            machine: r.machine,
            trusted: r.trusted,
        })
        .collect())
}

pub fn subtitle_download(file_id: i64) -> Result<SubtitleFile> {
    let (path, remaining) = core()?.subtitle_download(file_id)?;
    Ok(SubtitleFile { path, remaining })
}

pub fn tmdb_status() -> Result<TmdbStatus> {
    let s = core()?.tmdb_status()?;
    Ok(TmdbStatus { configured: s.configured, language: s.language })
}

/// Checks the key with TMDB and saves it in the OS keyring; None removes it.
pub fn set_tmdb_key(key: Option<String>) -> Result<()> {
    Ok(core()?.set_tmdb_key(key.as_deref())?)
}

pub fn set_tmdb_language(language: String) -> Result<()> {
    Ok(core()?.set_tmdb_language(&language)?)
}

pub fn tmdb_detail(item_id: i64) -> Result<Option<TmdbInfo>> {
    Ok(core()?.tmdb_for(item_id)?.map(|d| TmdbInfo {
        id: d.id,
        title: d.title,
        original_title: d.original_title,
        tagline: d.tagline,
        overview: d.overview,
        genres: d.genres,
        year: d.year,
        runtime_min: d.runtime_min,
        rating: d.rating,
        vote_count: d.vote_count,
        poster: d.poster,
        backdrop: d.backdrop,
        certification: d.certification,
        trailer: d.trailer,
        cast: d.cast.into_iter().map(|p| TmdbPerson { name: p.name, role: p.role, photo: p.photo }).collect(),
        makers: d.makers,
        seasons: d.seasons,
    }))
}

pub fn tmdb_season(item_id: i64, season: i32) -> Result<Vec<TmdbEpisodeInfo>> {
    Ok(core()?
        .tmdb_season(item_id, season)?
        .into_iter()
        .map(|e| TmdbEpisodeInfo {
            season: e.season,
            number: e.number,
            name: e.name,
            overview: e.overview,
            still: e.still,
            runtime_min: e.runtime_min,
            air_date: e.air_date,
        })
        .collect())
}

// ---- language -------------------------------------------------------------

/// The app language the user chose ("tr", "en"); None follows the system.
pub fn ui_language() -> Result<Option<String>> {
    Ok(core()?.ui_language()?)
}

/// Saves the choice and switches core messages (errors, sync stages) to
/// [effective].
pub fn set_ui_language(choice: Option<String>, effective: String) -> Result<()> {
    Ok(core()?.set_ui_language(choice.as_deref(), &effective)?)
}
