//! SQLite catalog store.
//!
//! The UI paints from here on launch and never waits for the network, which
//! is the main reason AbiPlayer felt slow. One connection behind the core's
//! mutex for now; the M1 layout (single writer actor + WAL reader pool) keeps
//! this API.

use std::path::Path;

use rusqlite::{params, Connection, OptionalExtension, Row};

use crate::catalog::{Catalog, ContentKind};
use crate::region::detect_region;
use crate::text::fold;

#[derive(Debug, thiserror::Error)]
pub enum StoreError {
    #[error(transparent)]
    Sqlite(#[from] rusqlite::Error),
    #[error("database schema version {0} is newer than this build supports")]
    SchemaTooNew(i64),
}

pub type Result<T> = std::result::Result<T, StoreError>;

const SCHEMA_VERSION: i64 = 4;

/// v4: TMDB responses and title matches, so details open offline and the
/// API is asked once per title, not on every visit.
const SCHEMA_V4: &str = "
CREATE TABLE IF NOT EXISTS web_cache (
    key         TEXT PRIMARY KEY,
    value       TEXT NOT NULL,
    fetched_at  INTEGER NOT NULL
);
";

/// v2: catch-up. Panel time zone for timeshift URLs, archive flag per programme.
const SCHEMA_V2: &str = "
ALTER TABLE source ADD COLUMN timezone TEXT;
ALTER TABLE epg_short ADD COLUMN archive INTEGER NOT NULL DEFAULT 0;
";

const SCHEMA_V1: &str = "
CREATE TABLE source (
    id              TEXT PRIMARY KEY,
    kind            TEXT NOT NULL,          -- 'xtream' | 'm3u'
    name            TEXT NOT NULL,
    url             TEXT NOT NULL,          -- server or playlist URL, never with a password
    username        TEXT,
    epg_url         TEXT,
    user_agent      TEXT,
    insecure_tls    INTEGER NOT NULL DEFAULT 0,
    sort            INTEGER NOT NULL DEFAULT 0,
    synced_at       INTEGER,
    last_error      TEXT,
    expires_at      INTEGER,
    max_connections INTEGER
);
CREATE TABLE category (
    id          INTEGER PRIMARY KEY,
    source_id   TEXT NOT NULL REFERENCES source(id) ON DELETE CASCADE,
    uid         INTEGER NOT NULL,
    name        TEXT NOT NULL,
    kind        INTEGER NOT NULL,
    adult       INTEGER NOT NULL,
    sort        INTEGER NOT NULL,
    region      TEXT,
    UNIQUE (source_id, uid)
);
CREATE TABLE channel (
    id              INTEGER PRIMARY KEY,
    source_id       TEXT NOT NULL REFERENCES source(id) ON DELETE CASCADE,
    uid             INTEGER NOT NULL,
    category_uid    INTEGER,
    name            TEXT NOT NULL,
    name_fold       TEXT NOT NULL,
    logo            TEXT,
    url             TEXT NOT NULL,
    kind            INTEGER NOT NULL,
    tvg_id          TEXT,
    chno            INTEGER,
    adult           INTEGER NOT NULL,
    sort            INTEGER NOT NULL,
    catchup         TEXT,
    catchup_days    INTEGER,
    catchup_source  TEXT,
    tvg_shift       REAL,
    user_agent      TEXT,
    referrer        TEXT,
    ext_id          INTEGER,
    container       TEXT,
    rating          REAL,
    year            INTEGER,
    added           INTEGER,
    region          TEXT,
    -- Display order: preferred region first, adult last, then provider
    -- order. Precomputed so keyset paging stays an index seek.
    order_key       INTEGER NOT NULL DEFAULT 0,
    UNIQUE (source_id, uid)
);
CREATE INDEX channel_browse ON channel (source_id, kind, category_uid, order_key);
CREATE INDEX channel_all ON channel (source_id, kind, order_key);
CREATE INDEX channel_added ON channel (source_id, kind, added);
CREATE VIRTUAL TABLE channel_fts USING fts5 (
    name_fold, content = 'channel', content_rowid = 'id', tokenize = 'trigram'
);

-- User data keys on (source_id, uid): uids survive catalog refreshes.
CREATE TABLE favorite (
    source_id   TEXT NOT NULL REFERENCES source(id) ON DELETE CASCADE,
    uid         INTEGER NOT NULL,
    added_at    INTEGER NOT NULL,
    PRIMARY KEY (source_id, uid)
);
CREATE TABLE progress (
    source_id   TEXT NOT NULL REFERENCES source(id) ON DELETE CASCADE,
    uid         INTEGER NOT NULL,           -- item uid, or episode ext id for series episodes
    item_uid    INTEGER NOT NULL,           -- the movie / series it belongs to
    title       TEXT NOT NULL,
    position_ms INTEGER NOT NULL,
    duration_ms INTEGER NOT NULL,
    updated_at  INTEGER NOT NULL,
    PRIMARY KEY (source_id, uid)
);
CREATE TABLE recent (
    source_id   TEXT NOT NULL REFERENCES source(id) ON DELETE CASCADE,
    uid         INTEGER NOT NULL,
    watched_at  INTEGER NOT NULL,
    PRIMARY KEY (source_id, uid)
);
CREATE TABLE setting (
    key     TEXT PRIMARY KEY,
    value   TEXT NOT NULL
);
CREATE TABLE epg_short (
    source_id   TEXT NOT NULL REFERENCES source(id) ON DELETE CASCADE,
    uid         INTEGER NOT NULL,
    start       INTEGER NOT NULL,
    stop        INTEGER NOT NULL,
    title       TEXT NOT NULL,
    description TEXT NOT NULL,
    fetched_at  INTEGER NOT NULL,
    PRIMARY KEY (source_id, uid, start)
);
";

#[derive(Debug, Clone, PartialEq)]
pub struct SourceRow {
    pub id: String,
    pub kind: String,
    pub name: String,
    pub url: String,
    pub username: Option<String>,
    pub epg_url: Option<String>,
    pub user_agent: Option<String>,
    pub insecure_tls: bool,
    pub synced_at: Option<i64>,
    pub last_error: Option<String>,
    pub expires_at: Option<i64>,
    pub max_connections: Option<i64>,
    pub timezone: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CategoryRow {
    pub uid: i64,
    pub name: String,
    pub adult: bool,
    pub count: u32,
}

/// Compact row for list screens: only what a list cell draws.
#[derive(Debug, Clone, PartialEq)]
pub struct ChannelRow {
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

/// Everything needed to play or describe one item.
#[derive(Debug, Clone, PartialEq)]
pub struct ItemRow {
    pub id: i64,
    pub source_id: String,
    pub uid: i64,
    pub kind: ContentKind,
    pub name: String,
    pub logo: Option<String>,
    pub url: String,
    pub tvg_id: Option<String>,
    pub catchup: Option<String>,
    pub catchup_days: Option<u32>,
    pub catchup_source: Option<String>,
    pub user_agent: Option<String>,
    pub referrer: Option<String>,
    pub ext_id: Option<i64>,
    pub container: Option<String>,
    pub rating: Option<f32>,
    pub year: Option<i32>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ProgressRow {
    pub source_id: String,
    pub uid: i64,
    pub item_uid: i64,
    pub title: String,
    pub position_ms: i64,
    pub duration_ms: i64,
    pub updated_at: i64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct EpgRow {
    pub start: i64,
    pub stop: i64,
    pub title: String,
    pub description: String,
    pub archive: bool,
}

const CHANNEL_ROW_COLS: &str = "id, uid, name, logo, chno, adult, order_key, rating, year, catchup IS NOT NULL";
const ITEM_COLS: &str = "id, source_id, uid, kind, name, logo, url, tvg_id, catchup, catchup_days, catchup_source, \
     user_agent, referrer, ext_id, container, rating, year";

pub struct Store {
    conn: Connection,
    /// Region shown first (e.g. "TR"); None keeps pure provider order.
    region_pref: Option<String>,
}

impl Store {
    pub fn open(path: impl AsRef<Path>) -> Result<Self> {
        Self::init(Connection::open(path)?)
    }

    pub fn open_in_memory() -> Result<Self> {
        Self::init(Connection::open_in_memory()?)
    }

    fn init(conn: Connection) -> Result<Self> {
        conn.execute_batch(
            "PRAGMA journal_mode = WAL;
             PRAGMA synchronous = NORMAL;
             PRAGMA temp_store = MEMORY;
             PRAGMA mmap_size = 268435456;
             PRAGMA foreign_keys = ON;",
        )?;
        let mut store = Store { conn, region_pref: None };
        store.migrate()?;
        store.region_pref = store.setting("region")?.filter(|r| !r.is_empty());
        Ok(store)
    }

    fn migrate(&mut self) -> Result<()> {
        let version: i64 = self.conn.pragma_query_value(None, "user_version", |r| r.get(0))?;
        if version > SCHEMA_VERSION {
            return Err(StoreError::SchemaTooNew(version));
        }
        if version < 1 {
            let tx = self.conn.transaction()?;
            tx.execute_batch(SCHEMA_V1)?;
            tx.pragma_update(None, "user_version", 1)?;
            tx.commit()?;
        }
        if version < 2 {
            let tx = self.conn.transaction()?;
            tx.execute_batch(SCHEMA_V2)?;
            tx.pragma_update(None, "user_version", 2)?;
            tx.commit()?;
        }
        if version < 3 {
            let tx = self.conn.transaction()?;
            Self::migrate_v3(&tx)?;
            tx.pragma_update(None, "user_version", 3)?;
            tx.commit()?;
        }
        if version < 4 {
            let tx = self.conn.transaction()?;
            tx.execute_batch(SCHEMA_V4)?;
            tx.pragma_update(None, "user_version", 4)?;
            tx.commit()?;
        }
        Ok(())
    }

    /// v3: region ordering. Libraries from before it lack the setting table,
    /// the region columns and the precomputed order; add them and derive both
    /// from the stored names, as a fresh sync would. A no-op on newer files.
    fn migrate_v3(tx: &Connection) -> Result<()> {
        tx.execute_batch("CREATE TABLE IF NOT EXISTS setting (key TEXT PRIMARY KEY, value TEXT NOT NULL);")?;
        if has_column(tx, "channel", "order_key")? {
            return Ok(());
        }
        tx.execute_batch(
            "ALTER TABLE category ADD COLUMN region TEXT;
             ALTER TABLE channel ADD COLUMN region TEXT;
             ALTER TABLE channel ADD COLUMN order_key INTEGER NOT NULL DEFAULT 0;
             DROP INDEX IF EXISTS channel_browse;
             DROP INDEX IF EXISTS channel_all;
             CREATE INDEX channel_browse ON channel (source_id, kind, category_uid, order_key);
             CREATE INDEX channel_all ON channel (source_id, kind, order_key);",
        )?;
        {
            let mut cats = tx.prepare("SELECT id, name FROM category")?;
            let rows: Vec<(i64, String)> = cats.query_map([], |r| Ok((r.get(0)?, r.get(1)?)))?.collect::<std::result::Result<_, _>>()?;
            let mut set = tx.prepare("UPDATE category SET region = ?2 WHERE id = ?1")?;
            for (id, name) in rows {
                if let Some(region) = detect_region(&name) {
                    set.execute(params![id, region])?;
                }
            }
            // The category's region, or one read from the item's own name.
            let mut items = tx.prepare(
                "SELECT ch.id, ch.name, c.region FROM channel ch
                 LEFT JOIN category c ON c.source_id = ch.source_id AND c.uid = ch.category_uid",
            )?;
            let rows: Vec<(i64, String, Option<String>)> =
                items.query_map([], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?.collect::<std::result::Result<_, _>>()?;
            let mut set = tx.prepare("UPDATE channel SET region = ?2 WHERE id = ?1")?;
            for (id, name, cat_region) in rows {
                if let Some(region) = cat_region.or_else(|| detect_region(&name).map(String::from)) {
                    set.execute(params![id, region])?;
                }
            }
        }
        Self::reorder(tx, None, None)
    }

    // ---- sources -------------------------------------------------------

    pub fn upsert_source(&self, s: &SourceRow) -> Result<()> {
        self.conn.execute(
            "INSERT INTO source (id, kind, name, url, username, epg_url, user_agent, insecure_tls, sort)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, (SELECT coalesce(max(sort), -1) + 1 FROM source))
             ON CONFLICT (id) DO UPDATE SET kind = excluded.kind, name = excluded.name, url = excluded.url,
                 username = excluded.username, epg_url = excluded.epg_url, user_agent = excluded.user_agent,
                 insecure_tls = excluded.insecure_tls",
            params![s.id, s.kind, s.name, s.url, s.username, s.epg_url, s.user_agent, s.insecure_tls],
        )?;
        Ok(())
    }

    pub fn sources(&self) -> Result<Vec<SourceRow>> {
        let mut stmt = self.conn.prepare_cached(
            "SELECT id, kind, name, url, username, epg_url, user_agent, insecure_tls, synced_at, last_error,
                    expires_at, max_connections, timezone FROM source ORDER BY sort",
        )?;
        let rows = stmt.query_map([], source_row)?;
        Ok(rows.collect::<std::result::Result<_, _>>()?)
    }

    pub fn source(&self, id: &str) -> Result<Option<SourceRow>> {
        Ok(self
            .conn
            .query_row(
                "SELECT id, kind, name, url, username, epg_url, user_agent, insecure_tls, synced_at, last_error,
                        expires_at, max_connections, timezone FROM source WHERE id = ?1",
                [id],
                source_row,
            )
            .optional()?)
    }

    pub fn delete_source(&self, id: &str) -> Result<()> {
        self.conn.execute("DELETE FROM source WHERE id = ?1", [id])?;
        self.conn.execute("INSERT INTO channel_fts (channel_fts) VALUES ('rebuild')", [])?;
        Ok(())
    }

    pub fn set_source_status(
        &self,
        id: &str,
        last_error: Option<&str>,
        expires_at: Option<i64>,
        max_connections: Option<i64>,
        timezone: Option<&str>,
    ) -> Result<()> {
        self.conn.execute(
            "UPDATE source SET last_error = ?2, expires_at = coalesce(?3, expires_at),
                 max_connections = coalesce(?4, max_connections), timezone = coalesce(?5, timezone) WHERE id = ?1",
            params![id, last_error, expires_at, max_connections, timezone],
        )?;
        Ok(())
    }

    // ---- settings & ordering ----------------------------------------------

    pub fn setting(&self, key: &str) -> Result<Option<String>> {
        Ok(self.conn.query_row("SELECT value FROM setting WHERE key = ?1", [key], |r| r.get(0)).optional()?)
    }

    pub fn set_setting(&self, key: &str, value: &str) -> Result<()> {
        self.conn.execute(
            "INSERT INTO setting (key, value) VALUES (?1, ?2) ON CONFLICT (key) DO UPDATE SET value = excluded.value",
            params![key, value],
        )?;
        Ok(())
    }

    pub fn region_pref(&self) -> Option<&str> {
        self.region_pref.as_deref()
    }

    /// Changes which region comes first and reorders every source.
    pub fn set_region_pref(&mut self, region: Option<&str>) -> Result<()> {
        let region = region.map(str::trim).filter(|r| !r.is_empty()).map(str::to_ascii_uppercase);
        self.set_setting("region", region.as_deref().unwrap_or(""))?;
        self.region_pref = region;
        let tx = self.conn.transaction()?;
        Self::reorder(&tx, None, self.region_pref.as_deref())?;
        tx.commit()?;
        Ok(())
    }

    /// Regions found in a source's items, most items first.
    pub fn regions(&self, source_id: &str) -> Result<Vec<(String, u32)>> {
        let mut stmt = self.conn.prepare_cached(
            "SELECT region, count(*) FROM channel WHERE source_id = ?1 AND region IS NOT NULL
             GROUP BY region ORDER BY count(*) DESC",
        )?;
        let rows = stmt.query_map([source_id], |r| Ok((r.get(0)?, r.get(1)?)))?;
        Ok(rows.collect::<std::result::Result<_, _>>()?)
    }

    /// Recomputes `order_key`: adult last, preferred region first, then the
    /// provider's own order. One window-function pass per call.
    fn reorder(conn: &Connection, source_id: Option<&str>, pref: Option<&str>) -> Result<()> {
        conn.execute_batch("DROP TABLE IF EXISTS temp.ord")?;
        conn.execute(
            "CREATE TEMP TABLE ord AS
             SELECT ch.id AS id,
                    ROW_NUMBER() OVER (
                        PARTITION BY ch.source_id, ch.kind
                        ORDER BY ch.adult,
                                 (ch.region IS ?2 AND ?2 IS NOT NULL) DESC,
                                 ch.sort
                    ) AS rn
             FROM channel ch
             WHERE ?1 IS NULL OR ch.source_id = ?1",
            params![source_id, pref],
        )?;
        conn.execute_batch(
            "CREATE UNIQUE INDEX temp.ord_id ON ord (id);
             UPDATE channel SET order_key = (SELECT rn FROM temp.ord WHERE temp.ord.id = channel.id)
             WHERE id IN (SELECT id FROM temp.ord);
             DROP TABLE temp.ord;",
        )?;
        Ok(())
    }

    // ---- catalog -------------------------------------------------------

    /// Replaces one source's catalog in a single transaction, so readers see
    /// either the old catalog or the new one, never a half-written mix.
    pub fn replace_catalog(&mut self, source_id: &str, catalog: &Catalog, synced_at: i64) -> Result<()> {
        let tx = self.conn.transaction()?;
        tx.execute("DELETE FROM channel WHERE source_id = ?1", [source_id])?;
        tx.execute("DELETE FROM category WHERE source_id = ?1", [source_id])?;
        {
            let mut cat = tx.prepare_cached(
                "INSERT OR IGNORE INTO category (source_id, uid, name, kind, adult, sort, region)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            )?;
            for c in &catalog.categories {
                cat.execute(params![source_id, c.uid, c.name, c.kind as u8, c.adult, c.sort, c.region])?;
            }
            let mut ch = tx.prepare_cached(
                "INSERT OR IGNORE INTO channel (source_id, uid, category_uid, name, name_fold, logo, url, kind, tvg_id,
                    chno, adult, sort, catchup, catchup_days, catchup_source, tvg_shift, user_agent, referrer,
                    ext_id, container, rating, year, added, region, order_key)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18,
                    ?19, ?20, ?21, ?22, ?23, ?24, ?12)",
            )?;
            for c in &catalog.channels {
                ch.execute(params![
                    source_id, c.uid, c.category_uid, c.name, fold(&c.name), c.logo, c.url, c.kind as u8,
                    c.tvg_id, c.chno, c.adult, c.sort, c.catchup, c.catchup_days, c.catchup_source,
                    c.tvg_shift, c.user_agent, c.referrer, c.ext_id, c.container, c.rating, c.year, c.added,
                    c.region
                ])?;
            }
        }
        tx.execute("INSERT INTO channel_fts (channel_fts) VALUES ('rebuild')", [])?;
        Self::reorder(&tx, Some(source_id), self.region_pref.as_deref())?;
        tx.execute(
            "UPDATE source SET synced_at = ?2, last_error = NULL,
                 epg_url = coalesce(epg_url, ?3) WHERE id = ?1",
            params![source_id, synced_at, catalog.epg_urls.first()],
        )?;
        tx.commit()?;
        Ok(())
    }

    pub fn channel_count(&self, source_id: &str) -> Result<u64> {
        Ok(self.conn.query_row("SELECT count(*) FROM channel WHERE source_id = ?1", [source_id], |r| r.get(0))?)
    }

    pub fn count_by_kind(&self, source_id: &str, kind: ContentKind) -> Result<u64> {
        Ok(self.conn.query_row(
            "SELECT count(*) FROM channel WHERE source_id = ?1 AND kind = ?2",
            params![source_id, kind as u8],
            |r| r.get(0),
        )?)
    }

    /// Categories in provider order, each with its item count. Adult
    /// categories go last, so a list never opens on them.
    pub fn categories(&self, source_id: &str, kind: ContentKind) -> Result<Vec<CategoryRow>> {
        let mut stmt = self.conn.prepare_cached(
            "SELECT c.uid, c.name, c.adult,
                    (SELECT count(*) FROM channel ch WHERE ch.source_id = c.source_id AND ch.kind = c.kind
                        AND ch.category_uid = c.uid)
             FROM category c WHERE c.source_id = ?1 AND c.kind = ?2
             ORDER BY c.adult, (c.region IS ?3 AND ?3 IS NOT NULL) DESC, c.sort",
        )?;
        let rows = stmt.query_map(params![source_id, kind as u8, self.region_pref], |r| {
            Ok(CategoryRow { uid: r.get(0)?, name: r.get(1)?, adult: r.get(2)?, count: r.get(3)? })
        })?;
        Ok(rows.collect::<std::result::Result<_, _>>()?)
    }

    /// One page of a category in provider order. `after_sort` is the keyset
    /// cursor (the last row's sort value), so deep pages cost the same as
    /// the first one.
    pub fn channels_page(
        &self,
        source_id: &str,
        kind: ContentKind,
        category_uid: Option<i64>,
        after_sort: Option<u32>,
        limit: u32,
    ) -> Result<Vec<ChannelRow>> {
        // Two statements instead of `(?3 IS NULL OR category_uid = ?3)`: the
        // OR form stops SQLite from using either index for the keyset seek.
        let after = after_sort.map(i64::from).unwrap_or(-1);
        let rows = match category_uid {
            Some(cat) => {
                let mut stmt = self.conn.prepare_cached(&format!(
                    "SELECT {CHANNEL_ROW_COLS} FROM channel
                     WHERE source_id = ?1 AND kind = ?2 AND category_uid = ?3 AND order_key > ?4
                     ORDER BY order_key LIMIT ?5"
                ))?;
                let rows = stmt.query_map(params![source_id, kind as u8, cat, after, limit], channel_row)?;
                rows.collect::<std::result::Result<Vec<_>, _>>()?
            }
            None => {
                let mut stmt = self.conn.prepare_cached(&format!(
                    "SELECT {CHANNEL_ROW_COLS} FROM channel
                     WHERE source_id = ?1 AND kind = ?2 AND order_key > ?3
                     ORDER BY order_key LIMIT ?4"
                ))?;
                let rows = stmt.query_map(params![source_id, kind as u8, after, limit], channel_row)?;
                rows.collect::<std::result::Result<Vec<_>, _>>()?
            }
        };
        Ok(rows)
    }

    /// Newest additions, for the home screen.
    pub fn recently_added(&self, source_id: &str, kind: ContentKind, limit: u32) -> Result<Vec<ChannelRow>> {
        let mut stmt = self.conn.prepare_cached(&format!(
            "SELECT {CHANNEL_ROW_COLS} FROM channel WHERE source_id = ?1 AND kind = ?2 AND adult = 0
             ORDER BY added DESC NULLS LAST, order_key LIMIT ?3"
        ))?;
        let rows = stmt.query_map(params![source_id, kind as u8, limit], channel_row)?;
        Ok(rows.collect::<std::result::Result<_, _>>()?)
    }

    /// Accent- and case-insensitive substring search over names, optionally
    /// restricted to one kind.
    pub fn search(&self, query: &str, kind: Option<ContentKind>, limit: u32) -> Result<Vec<ChannelRow>> {
        let q = fold(query.trim());
        if q.is_empty() {
            return Ok(Vec::new());
        }
        let kind = kind.map(|k| k as u8);
        // The trigram tokenizer needs at least three characters; shorter
        // queries fall back to a prefix scan on the folded name.
        let rows = if q.chars().count() >= 3 {
            let phrase = format!("\"{}\"", q.replace('"', "\"\""));
            let mut stmt = self.conn.prepare_cached(&format!(
                "SELECT {} FROM channel_fts f JOIN channel c ON c.id = f.rowid
                 WHERE channel_fts MATCH ?1 AND (?2 IS NULL OR c.kind = ?2)
                 ORDER BY c.order_key LIMIT ?3",
                CHANNEL_ROW_COLS.split(", ").map(|c| format!("c.{c}")).collect::<Vec<_>>().join(", ")
            ))?;
            let rows = stmt.query_map(params![phrase, kind, limit], channel_row)?;
            rows.collect::<std::result::Result<Vec<_>, _>>()?
        } else {
            let mut stmt = self.conn.prepare_cached(&format!(
                "SELECT {CHANNEL_ROW_COLS} FROM channel
                 WHERE name_fold LIKE ?1 ESCAPE '\\' AND (?2 IS NULL OR kind = ?2)
                 ORDER BY order_key LIMIT ?3"
            ))?;
            let pattern = format!("{}%", q.replace('\\', "\\\\").replace('%', "\\%").replace('_', "\\_"));
            let rows = stmt.query_map(params![pattern, kind, limit], channel_row)?;
            rows.collect::<std::result::Result<Vec<_>, _>>()?
        };
        Ok(rows)
    }

    pub fn item(&self, id: i64) -> Result<Option<ItemRow>> {
        Ok(self
            .conn
            .query_row(&format!("SELECT {ITEM_COLS} FROM channel WHERE id = ?1"), [id], item_row)
            .optional()?)
    }

    pub fn item_by_uid(&self, source_id: &str, uid: i64) -> Result<Option<ItemRow>> {
        Ok(self
            .conn
            .query_row(
                &format!("SELECT {ITEM_COLS} FROM channel WHERE source_id = ?1 AND uid = ?2"),
                params![source_id, uid],
                item_row,
            )
            .optional()?)
    }

    pub fn stream_url(&self, channel_id: i64) -> Result<Option<String>> {
        Ok(self
            .conn
            .query_row("SELECT url FROM channel WHERE id = ?1", [channel_id], |r| r.get(0))
            .optional()?)
    }

    // ---- user data ---------------------------------------------------

    pub fn set_favorite(&self, source_id: &str, uid: i64, on: bool, now: i64) -> Result<()> {
        if on {
            self.conn.execute(
                "INSERT OR IGNORE INTO favorite (source_id, uid, added_at) VALUES (?1, ?2, ?3)",
                params![source_id, uid, now],
            )?;
        } else {
            self.conn.execute("DELETE FROM favorite WHERE source_id = ?1 AND uid = ?2", params![source_id, uid])?;
        }
        Ok(())
    }

    pub fn favorites(&self, source_id: &str, kind: ContentKind) -> Result<Vec<ChannelRow>> {
        let mut stmt = self.conn.prepare_cached(&format!(
            "SELECT {} FROM favorite f JOIN channel c ON c.source_id = f.source_id AND c.uid = f.uid
             WHERE f.source_id = ?1 AND c.kind = ?2 ORDER BY f.added_at",
            CHANNEL_ROW_COLS.split(", ").map(|c| format!("c.{c}")).collect::<Vec<_>>().join(", ")
        ))?;
        let rows = stmt.query_map(params![source_id, kind as u8], channel_row)?;
        Ok(rows.collect::<std::result::Result<_, _>>()?)
    }

    pub fn is_favorite(&self, source_id: &str, uid: i64) -> Result<bool> {
        Ok(self
            .conn
            .query_row("SELECT 1 FROM favorite WHERE source_id = ?1 AND uid = ?2", params![source_id, uid], |_| Ok(()))
            .optional()?
            .is_some())
    }

    pub fn touch_recent(&self, source_id: &str, uid: i64, now: i64) -> Result<()> {
        self.conn.execute(
            "INSERT INTO recent (source_id, uid, watched_at) VALUES (?1, ?2, ?3)
             ON CONFLICT (source_id, uid) DO UPDATE SET watched_at = excluded.watched_at",
            params![source_id, uid, now],
        )?;
        Ok(())
    }

    pub fn recent(&self, source_id: &str, kind: ContentKind, limit: u32) -> Result<Vec<ChannelRow>> {
        let mut stmt = self.conn.prepare_cached(&format!(
            "SELECT {} FROM recent r JOIN channel c ON c.source_id = r.source_id AND c.uid = r.uid
             WHERE r.source_id = ?1 AND c.kind = ?2 ORDER BY r.watched_at DESC LIMIT ?3",
            CHANNEL_ROW_COLS.split(", ").map(|c| format!("c.{c}")).collect::<Vec<_>>().join(", ")
        ))?;
        let rows = stmt.query_map(params![source_id, kind as u8, limit], channel_row)?;
        Ok(rows.collect::<std::result::Result<_, _>>()?)
    }

    pub fn save_progress(&self, p: &ProgressRow) -> Result<()> {
        self.conn.execute(
            "INSERT INTO progress (source_id, uid, item_uid, title, position_ms, duration_ms, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
             ON CONFLICT (source_id, uid) DO UPDATE SET position_ms = excluded.position_ms,
                 duration_ms = excluded.duration_ms, updated_at = excluded.updated_at, title = excluded.title",
            params![p.source_id, p.uid, p.item_uid, p.title, p.position_ms, p.duration_ms, p.updated_at],
        )?;
        Ok(())
    }

    pub fn progress(&self, source_id: &str, uid: i64) -> Result<Option<ProgressRow>> {
        Ok(self
            .conn
            .query_row(
                "SELECT source_id, uid, item_uid, title, position_ms, duration_ms, updated_at FROM progress
                 WHERE source_id = ?1 AND uid = ?2",
                params![source_id, uid],
                progress_row,
            )
            .optional()?)
    }

    /// Unfinished items (between 2 % and 95 %), newest first: "Devam et".
    pub fn continue_watching(&self, source_id: &str, limit: u32) -> Result<Vec<ProgressRow>> {
        let mut stmt = self.conn.prepare_cached(
            "SELECT source_id, uid, item_uid, title, position_ms, duration_ms, updated_at FROM progress
             WHERE source_id = ?1 AND duration_ms > 0
               AND position_ms * 100 > duration_ms * 2 AND position_ms * 100 < duration_ms * 95
             ORDER BY updated_at DESC LIMIT ?2",
        )?;
        let rows = stmt.query_map(params![source_id, limit], progress_row)?;
        Ok(rows.collect::<std::result::Result<_, _>>()?)
    }

    // ---- short EPG cache ----------------------------------------------

    /// Stores a fresh EPG fetch for one channel. A full table (`full`)
    /// replaces everything; a short now/next fetch replaces only what has not
    /// ended yet, keeping the archive. Past rows nobody can replay, and
    /// anything older than the longest archive window, are dropped.
    pub fn replace_epg_short(&mut self, source_id: &str, uid: i64, entries: &[EpgRow], now: i64, full: bool) -> Result<()> {
        let tx = self.conn.transaction()?;
        tx.execute(
            "DELETE FROM epg_short WHERE source_id = ?1 AND uid = ?2
               AND (?3 OR stop > ?4 OR archive = 0 OR stop < ?4 - 8 * 86400)",
            params![source_id, uid, full, now],
        )?;
        {
            let mut ins = tx.prepare_cached(
                "INSERT OR REPLACE INTO epg_short (source_id, uid, start, stop, title, description, archive, fetched_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            )?;
            for e in entries {
                ins.execute(params![source_id, uid, e.start, e.stop, e.title, e.description, e.archive, now])?;
            }
        }
        tx.commit()?;
        Ok(())
    }

    /// Cached programmes still running or upcoming, and when they were fetched.
    pub fn epg_short(&self, source_id: &str, uid: i64, now: i64) -> Result<(Vec<EpgRow>, Option<i64>)> {
        let mut stmt = self.conn.prepare_cached(
            "SELECT start, stop, title, description, archive, fetched_at FROM epg_short
             WHERE source_id = ?1 AND uid = ?2 AND stop > ?3 ORDER BY start",
        )?;
        let mut fetched = None;
        let rows = stmt.query_map(params![source_id, uid, now], |r| {
            Ok((
                EpgRow { start: r.get(0)?, stop: r.get(1)?, title: r.get(2)?, description: r.get(3)?, archive: r.get(4)? },
                r.get::<_, i64>(5)?,
            ))
        })?;
        let mut out = Vec::new();
        for row in rows {
            let (e, f) = row?;
            fetched = Some(f);
            out.push(e);
        }
        Ok((out, fetched))
    }

    /// A cached web response no older than [max_age] seconds.
    pub fn cache_get(&self, key: &str, max_age: i64, now: i64) -> Result<Option<String>> {
        Ok(self
            .conn
            .query_row(
                "SELECT value FROM web_cache WHERE key = ?1 AND fetched_at > ?2",
                params![key, now - max_age],
                |r| r.get(0),
            )
            .optional()?)
    }

    pub fn cache_put(&self, key: &str, value: &str, now: i64) -> Result<()> {
        self.conn.execute(
            "INSERT OR REPLACE INTO web_cache (key, value, fetched_at) VALUES (?1, ?2, ?3)",
            params![key, value, now],
        )?;
        Ok(())
    }

    /// When the archive (full table) of a channel was last fetched.
    pub fn epg_archive_fetched(&self, source_id: &str, uid: i64) -> Result<Option<i64>> {
        Ok(self.conn.query_row(
            "SELECT max(fetched_at) FROM epg_short WHERE source_id = ?1 AND uid = ?2 AND archive = 1",
            params![source_id, uid],
            |r| r.get(0),
        )?)
    }

    /// Cached programmes that ended between [from] and [to], newest first.
    pub fn epg_past(&self, source_id: &str, uid: i64, from: i64, to: i64) -> Result<Vec<EpgRow>> {
        let mut stmt = self.conn.prepare_cached(
            "SELECT start, stop, title, description, archive FROM epg_short
             WHERE source_id = ?1 AND uid = ?2 AND stop <= ?4 AND start >= ?3 ORDER BY start DESC",
        )?;
        let rows = stmt.query_map(params![source_id, uid, from, to], |r| {
            Ok(EpgRow { start: r.get(0)?, stop: r.get(1)?, title: r.get(2)?, description: r.get(3)?, archive: r.get(4)? })
        })?;
        Ok(rows.collect::<std::result::Result<_, _>>()?)
    }
}

fn has_column(conn: &Connection, table: &str, column: &str) -> Result<bool> {
    let mut stmt = conn.prepare(&format!("PRAGMA table_info({table})"))?;
    let names = stmt.query_map([], |r| r.get::<_, String>(1))?.collect::<std::result::Result<Vec<_>, _>>()?;
    Ok(names.iter().any(|n| n == column))
}

fn source_row(r: &Row<'_>) -> rusqlite::Result<SourceRow> {
    Ok(SourceRow {
        id: r.get(0)?,
        kind: r.get(1)?,
        name: r.get(2)?,
        url: r.get(3)?,
        username: r.get(4)?,
        epg_url: r.get(5)?,
        user_agent: r.get(6)?,
        insecure_tls: r.get(7)?,
        synced_at: r.get(8)?,
        last_error: r.get(9)?,
        expires_at: r.get(10)?,
        max_connections: r.get(11)?,
        timezone: r.get(12)?,
    })
}

fn channel_row(r: &Row<'_>) -> rusqlite::Result<ChannelRow> {
    Ok(ChannelRow {
        id: r.get(0)?,
        uid: r.get(1)?,
        name: r.get(2)?,
        logo: r.get(3)?,
        chno: r.get(4)?,
        adult: r.get(5)?,
        sort: r.get(6)?,
        rating: r.get(7)?,
        year: r.get(8)?,
        has_catchup: r.get(9)?,
    })
}

fn item_row(r: &Row<'_>) -> rusqlite::Result<ItemRow> {
    let kind: u8 = r.get(3)?;
    Ok(ItemRow {
        id: r.get(0)?,
        source_id: r.get(1)?,
        uid: r.get(2)?,
        kind: match kind {
            1 => ContentKind::Movie,
            2 => ContentKind::Series,
            _ => ContentKind::Live,
        },
        name: r.get(4)?,
        logo: r.get(5)?,
        url: r.get(6)?,
        tvg_id: r.get(7)?,
        catchup: r.get(8)?,
        catchup_days: r.get(9)?,
        catchup_source: r.get(10)?,
        user_agent: r.get(11)?,
        referrer: r.get(12)?,
        ext_id: r.get(13)?,
        container: r.get(14)?,
        rating: r.get(15)?,
        year: r.get(16)?,
    })
}

fn progress_row(r: &Row<'_>) -> rusqlite::Result<ProgressRow> {
    Ok(ProgressRow {
        source_id: r.get(0)?,
        uid: r.get(1)?,
        item_uid: r.get(2)?,
        title: r.get(3)?,
        position_ms: r.get(4)?,
        duration_ms: r.get(5)?,
        updated_at: r.get(6)?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::m3u::parse;

    fn sample() -> Catalog {
        Catalog::from_m3u(parse(
            "#EXTINF:-1 group-title=\"Ulusal\",TRT 1 HD\nhttp://s/1.ts\n\
             #EXTINF:-1 group-title=\"Ulusal\",FOX Türk\nhttp://s/2.ts\n\
             #EXTINF:-1 group-title=\"Spor\",beIN Sports 1\nhttp://s/3.ts\n\
             #EXTINF:-1 group-title=\"XXX\",Gizli\nhttp://s/4.ts\n",
        ))
    }

    fn source(id: &str) -> SourceRow {
        SourceRow {
            id: id.into(),
            kind: "m3u".into(),
            name: "Test".into(),
            url: "http://s/list.m3u".into(),
            username: None,
            epg_url: None,
            user_agent: None,
            insecure_tls: false,
            synced_at: None,
            last_error: None,
            expires_at: None,
            max_connections: None,
            timezone: None,
        }
    }

    fn store() -> Store {
        let mut store = Store::open_in_memory().unwrap();
        store.upsert_source(&source("src")).unwrap();
        store.replace_catalog("src", &sample(), 1).unwrap();
        store
    }

    #[test]
    fn replace_page_and_search() {
        let mut store = store();
        assert_eq!(store.channel_count("src").unwrap(), 4);

        let page = store.channels_page("src", ContentKind::Live, None, None, 2).unwrap();
        assert_eq!(page.iter().map(|r| r.name.as_str()).collect::<Vec<_>>(), vec!["TRT 1 HD", "FOX Türk"]);
        let next = store.channels_page("src", ContentKind::Live, None, Some(page[1].sort), 2).unwrap();
        assert_eq!(next[0].name, "beIN Sports 1");

        assert_eq!(store.search("fox turk", None, 10).unwrap()[0].name, "FOX Türk");
        assert_eq!(store.search("TÜRK", Some(ContentKind::Live), 10).unwrap()[0].name, "FOX Türk");
        assert!(store.search("türk", Some(ContentKind::Movie), 10).unwrap().is_empty());
        assert_eq!(store.search("tr", None, 10).unwrap()[0].name, "TRT 1 HD");

        // A second sync replaces rather than duplicates.
        store.replace_catalog("src", &sample(), 2).unwrap();
        assert_eq!(store.channel_count("src").unwrap(), 4);
        assert_eq!(store.search("sports", None, 10).unwrap().len(), 1);
    }

    #[test]
    fn v1_database_upgrades_in_place() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("library.sqlite");
        {
            let conn = Connection::open(&path).unwrap();
            conn.execute_batch(SCHEMA_V1).unwrap();
            conn.pragma_update(None, "user_version", 1).unwrap();
        }
        let store = Store::open(&path).unwrap();
        store.upsert_source(&source("src")).unwrap();
        store.set_source_status("src", None, None, None, Some("Europe/Istanbul")).unwrap();
        assert_eq!(store.source("src").unwrap().unwrap().timezone.as_deref(), Some("Europe/Istanbul"));
    }

    #[test]
    fn categories_put_adult_last_with_counts() {
        let store = store();
        let cats = store.categories("src", ContentKind::Live).unwrap();
        let view: Vec<_> = cats.iter().map(|c| (c.name.as_str(), c.count, c.adult)).collect();
        assert_eq!(view, vec![("Ulusal", 2, false), ("Spor", 1, false), ("XXX", 1, true)]);
    }

    #[test]
    fn favorites_recent_and_progress_survive_resync() {
        let mut store = store();
        let fox = store.search("fox", None, 1).unwrap().remove(0);
        store.set_favorite("src", fox.uid, true, 10).unwrap();
        store.touch_recent("src", fox.uid, 11).unwrap();
        store
            .save_progress(&ProgressRow {
                source_id: "src".into(),
                uid: fox.uid,
                item_uid: fox.uid,
                title: "FOX Türk".into(),
                position_ms: 30_000,
                duration_ms: 100_000,
                updated_at: 12,
            })
            .unwrap();

        store.replace_catalog("src", &sample(), 3).unwrap();
        assert_eq!(store.favorites("src", ContentKind::Live).unwrap()[0].name, "FOX Türk");
        assert!(store.is_favorite("src", fox.uid).unwrap());
        assert_eq!(store.recent("src", ContentKind::Live, 5).unwrap()[0].uid, fox.uid);
        assert_eq!(store.continue_watching("src", 5).unwrap().len(), 1);

        store.set_favorite("src", fox.uid, false, 13).unwrap();
        assert!(store.favorites("src", ContentKind::Live).unwrap().is_empty());
    }

    #[test]
    fn epg_cache_drops_finished_programmes_but_keeps_the_archive() {
        let mut store = store();
        let uid = store.search("trt", None, 1).unwrap()[0].uid;
        let t = 1_000_000;
        let row = |start: i64, title: &str, archive: bool| EpgRow {
            start,
            stop: start + 100,
            title: title.into(),
            description: String::new(),
            archive,
        };
        // Full table: one replayable past programme, one not, one running.
        let table = vec![row(t - 300, "Kayıtsız", false), row(t - 100, "Bitti", true), row(t, "Şimdi", false)];
        store.replace_epg_short("src", uid, &table, t + 50, true).unwrap();
        let (left, fetched) = store.epg_short("src", uid, t + 50).unwrap();
        assert_eq!(left.iter().map(|e| e.title.as_str()).collect::<Vec<_>>(), vec!["Şimdi"]);
        assert_eq!(fetched, Some(t + 50));
        assert_eq!(store.epg_archive_fetched("src", uid).unwrap(), Some(t + 50));

        // A later short refresh replaces what is upcoming, not the archive.
        store.replace_epg_short("src", uid, &[row(t + 100, "Sonra", false)], t + 150, false).unwrap();
        let past = store.epg_past("src", uid, 0, t + 150).unwrap();
        assert_eq!(past.iter().map(|e| (e.title.as_str(), e.archive)).collect::<Vec<_>>(), vec![("Bitti", true)]);
        assert_eq!(store.epg_short("src", uid, t + 150).unwrap().0[0].title, "Sonra");
    }

    #[test]
    fn preferred_region_comes_first_and_adult_last() {
        let mut store = Store::open_in_memory().unwrap();
        store.upsert_source(&source("src")).unwrap();
        // Typical provider order: adult group on top, regions interleaved.
        let catalog = Catalog::from_m3u(parse(
            "#EXTINF:-1 group-title=\"XXX\",Gizli\nhttp://s/x.ts\n\
             #EXTINF:-1 group-title=\"DE: Sport\",Sport 1\nhttp://s/d1.ts\n\
             #EXTINF:-1 group-title=\"Dünya\",World 1\nhttp://s/w1.ts\n\
             #EXTINF:-1 group-title=\"TR: Ulusal\",TRT 1\nhttp://s/t1.ts\n\
             #EXTINF:-1 group-title=\"TR: Spor\",beIN Sports 1\nhttp://s/t2.ts\n",
        ));
        store.replace_catalog("src", &catalog, 1).unwrap();

        let names = |store: &Store| -> Vec<String> {
            store.channels_page("src", ContentKind::Live, None, None, 10).unwrap().into_iter().map(|r| r.name).collect()
        };
        // No preference: provider order, adult still last.
        assert_eq!(names(&store), ["Sport 1", "World 1", "TRT 1", "beIN Sports 1", "Gizli"]);

        store.set_region_pref(Some("tr")).unwrap();
        assert_eq!(store.region_pref(), Some("TR"));
        assert_eq!(names(&store), ["TRT 1", "beIN Sports 1", "Sport 1", "World 1", "Gizli"]);
        let cats: Vec<_> = store.categories("src", ContentKind::Live).unwrap().into_iter().map(|c| c.name).collect();
        assert_eq!(cats, ["TR: Ulusal", "TR: Spor", "DE: Sport", "Dünya", "XXX"]);

        // A resync keeps the preference.
        store.replace_catalog("src", &catalog, 2).unwrap();
        assert_eq!(names(&store)[0], "TRT 1");
        assert_eq!(store.regions("src").unwrap(), vec![("TR".to_string(), 2), ("DE".to_string(), 1)]);

        store.set_region_pref(None).unwrap();
        assert_eq!(names(&store)[0], "Sport 1");
    }

    #[test]
    fn deleting_a_source_removes_its_catalog() {
        let store = store();
        store.delete_source("src").unwrap();
        assert_eq!(store.channel_count("src").unwrap(), 0);
        assert!(store.search("trt", None, 5).unwrap().is_empty());
    }
}
