//! Dart-facing API. Plain data types only; every call runs on the bridge's
//! worker pool, so blocking SQLite and network work never touches the UI
//! thread.

use std::path::PathBuf;
use std::sync::OnceLock;

use anyhow::{anyhow, Result};
use flutter_rust_bridge::frb;
use kp_core::core::{Core, NewSource, SourceKind, SyncStage};
use kp_core::secret::OsKeyring;
use kp_core::store::{CategoryRow, ChannelRow, SourceRow};
use kp_core::ContentKind;

use crate::frb_generated::StreamSink;

static CORE: OnceLock<Core> = OnceLock::new();

fn core() -> Result<&'static Core> {
    CORE.get().ok_or_else(|| anyhow!("kütüphane başlatılmadı"))
}

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// Opens (or creates) the library under [data_dir]. Safe to call twice.
pub fn open_library(data_dir: String) -> Result<()> {
    if CORE.get().is_some() {
        return Ok(());
    }
    let dir = PathBuf::from(data_dir);
    std::fs::create_dir_all(&dir)?;
    let core = Core::open(dir.join("library.sqlite"), Box::new(OsKeyring))?;
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

#[derive(Debug, Clone)]
pub struct SourceInfo {
    pub id: String,
    pub is_xtream: bool,
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
}

#[derive(Debug, Clone)]
pub struct NewSourceInput {
    pub is_xtream: bool,
    pub name: String,
    pub url: String,
    pub username: Option<String>,
    pub password: Option<String>,
    pub user_agent: Option<String>,
    pub insecure_tls: bool,
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
    Ok(SourceInfo {
        live_count: core.count(&s.id, ContentKind::Live)?,
        movie_count: core.count(&s.id, ContentKind::Movie)?,
        series_count: core.count(&s.id, ContentKind::Series)?,
        is_xtream: s.kind == "xtream",
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
        kind: if input.is_xtream { SourceKind::Xtream } else { SourceKind::M3u },
        name: input.name,
        url: input.url,
        username: input.username,
        password: input.password,
        epg_url: None,
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

pub fn sync_source(source_id: String, sink: StreamSink<SyncEvent>) -> Result<()> {
    let core = core()?;
    let result = core.sync(&source_id, &|s| {
        let _ = sink.add(stage_event(s));
    });
    let _ = match result {
        Ok(_) => match core.sources()?.into_iter().find(|s| s.id == source_id) {
            Some(s) => sink.add(SyncEvent::Done { source: source_info(core, s)? }),
            None => sink.add(SyncEvent::Failed { message: "Kaynak bulunamadı".into() }),
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

pub fn items_page(source_id: String, kind: Kind, category_uid: Option<i64>, after_sort: Option<u32>, limit: u32) -> Result<Vec<Item>> {
    Ok(items(core()?.page(&source_id, kind.into(), category_uid, after_sort, limit)?))
}

pub fn search(query: String, kind: Option<Kind>, limit: u32) -> Result<Vec<Item>> {
    Ok(items(core()?.search(&query, kind.map(Into::into), limit)?))
}

pub fn recently_added(source_id: String, kind: Kind, limit: u32) -> Result<Vec<Item>> {
    Ok(items(core()?.recently_added(&source_id, kind.into(), limit)?))
}

pub fn favorites(source_id: String, kind: Kind) -> Result<Vec<Item>> {
    Ok(items(core()?.favorites(&source_id, kind.into())?))
}

pub fn recent(source_id: String, kind: Kind, limit: u32) -> Result<Vec<Item>> {
    Ok(items(core()?.recent(&source_id, kind.into(), limit)?))
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
