//! XMLTV guides, one SQLite file per source beside the library.
//!
//! A guide is rebuilt from scratch on every download into `<file>.tmp` with
//! its own connection, then renamed over the old one. The library database
//! is never locked during the (long) ingest, and readers only ever see a
//! complete guide.

use std::collections::HashMap;
use std::io::BufRead;
use std::path::Path;

use rusqlite::{params, Connection, OpenFlags};

use crate::store::EpgRow;
use crate::text::fold;
use crate::xmltv::{self, XmltvError};

/// Programmes kept around now: the longest catch-up windows are 7 days.
const KEEP_PAST_SECS: i64 = 8 * 86_400;
const KEEP_AHEAD_SECS: i64 = 14 * 86_400;

#[derive(Debug, thiserror::Error)]
pub enum GuideError {
    #[error(transparent)]
    Xmltv(#[from] XmltvError),
    #[error("yayın akışı kaydedilemedi: {0}")]
    Db(#[from] rusqlite::Error),
    #[error("yayın akışı dosyası: {0}")]
    Io(#[from] std::io::Error),
}

pub type Result<T> = std::result::Result<T, GuideError>;

/// A playlist channel to find in the guide.
#[derive(Debug, Clone)]
pub struct GuideChannel {
    pub uid: i64,
    pub tvg_id: Option<String>,
    pub name: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Default)]
pub struct BuildStats {
    pub programmes: u64,
    /// Playlist channels that found their guide channel.
    pub matched: u64,
    pub channels: u64,
}

const SCHEMA: &str = "
CREATE TABLE xchannel (
    key   INTEGER PRIMARY KEY,
    id    TEXT NOT NULL UNIQUE
);
CREATE TABLE xname (
    name  TEXT NOT NULL,
    key   INTEGER NOT NULL
);
CREATE TABLE programme (
    key   INTEGER NOT NULL,
    start INTEGER NOT NULL,
    stop  INTEGER NOT NULL,
    title TEXT NOT NULL,
    descr TEXT NOT NULL
);
-- Playlist channel uid -> guide channel.
CREATE TABLE map (
    uid   INTEGER PRIMARY KEY,
    key   INTEGER NOT NULL
);
";

/// Builds the next guide for [path] from an XMLTV stream, matching
/// [channels], into `<path>.tmp`; [install] puts it in place. The current
/// guide keeps serving meanwhile.
pub fn build(path: &Path, input: impl BufRead, channels: &[GuideChannel], now: i64) -> Result<BuildStats> {
    let tmp = tmp_path(path);
    let _ = std::fs::remove_file(&tmp);
    build_into(&tmp, input, channels, now).inspect_err(|_| {
        let _ = std::fs::remove_file(&tmp);
    })
}

/// Swaps a [build] result in. Readers of [path] must be closed first:
/// Windows cannot replace an open file.
pub fn install(path: &Path) -> Result<()> {
    Ok(std::fs::rename(tmp_path(path), path)?)
}

fn tmp_path(path: &Path) -> std::path::PathBuf {
    path.with_extension("sqlite.tmp")
}

fn build_into(tmp: &Path, input: impl BufRead, channels: &[GuideChannel], now: i64) -> Result<BuildStats> {
    let mut conn = Connection::open(tmp)?;
    // A half-built guide is thrown away anyway: no journal, no fsync.
    conn.execute_batch("PRAGMA journal_mode = OFF; PRAGMA synchronous = OFF; PRAGMA temp_store = MEMORY;")?;
    conn.execute_batch(SCHEMA)?;
    let tx = conn.transaction()?;
    let mut stats = BuildStats { channels: channels.len() as u64, ..Default::default() };
    {
        // Both callbacks write through the same statements and key map.
        struct Ingest<'c> {
            keys: HashMap<String, i64>,
            add_channel: rusqlite::Statement<'c>,
            add_name: rusqlite::Statement<'c>,
            add_prog: rusqlite::Statement<'c>,
            programmes: u64,
            failure: Option<rusqlite::Error>,
        }
        impl Ingest<'_> {
            /// Guides disagree with themselves on case ("TRT1.tr" vs "trt1.tr").
            fn key(&mut self, id: &str) -> rusqlite::Result<i64> {
                let id = id.to_lowercase();
                let id = id.as_str();
                if let Some(k) = self.keys.get(id) {
                    return Ok(*k);
                }
                let k = self.keys.len() as i64 + 1;
                self.add_channel.execute(params![k, id])?;
                self.keys.insert(id.to_string(), k);
                Ok(k)
            }
        }
        let state = std::cell::RefCell::new(Ingest {
            keys: HashMap::new(),
            add_channel: tx.prepare("INSERT INTO xchannel (key, id) VALUES (?1, ?2)")?,
            add_name: tx.prepare("INSERT INTO xname (name, key) VALUES (?1, ?2)")?,
            add_prog: tx.prepare("INSERT INTO programme (key, start, stop, title, descr) VALUES (?1, ?2, ?3, ?4, ?5)")?,
            programmes: 0,
            failure: None,
        });
        let (from, to) = (now - KEEP_PAST_SECS, now + KEEP_AHEAD_SECS);
        xmltv::parse(
            input,
            |c| {
                let mut st = state.borrow_mut();
                if st.failure.is_some() {
                    return;
                }
                let r = st.key(&c.id).and_then(|k| {
                    for n in &c.names {
                        st.add_name.execute(params![match_name(n), k])?;
                    }
                    Ok(())
                });
                if let Err(e) = r {
                    st.failure = Some(e);
                }
            },
            |p| {
                let mut st = state.borrow_mut();
                if st.failure.is_some() || p.start > to || (p.stop > p.start && p.stop < from) {
                    return;
                }
                let r = st.key(&p.channel).and_then(|k| st.add_prog.execute(params![k, p.start, p.stop, p.title, p.description]));
                match r {
                    Ok(_) => st.programmes += 1,
                    Err(e) => st.failure = Some(e),
                }
            },
        )?;
        let st = state.into_inner();
        if let Some(e) = st.failure {
            return Err(e.into());
        }
        stats.programmes = st.programmes;
    }
    tx.execute_batch(
        "CREATE INDEX programme_by_key ON programme (key, start);
         CREATE INDEX xname_by_name ON xname (name);
         -- No stop time: it runs until the channel's next programme.
         UPDATE programme SET stop = coalesce(
             (SELECT min(n.start) FROM programme n WHERE n.key = programme.key AND n.start > programme.start),
             programme.start + 1800)
         WHERE stop <= start;",
    )?;
    stats.matched = match_channels(&tx, channels)?;
    tx.commit()?;
    conn.execute_batch("ANALYZE;")?;
    Ok(stats)
}

/// tvg-id first (case-insensitive), then the channel name against every
/// display-name, both normalized ("TR: TRT 1 HD" ~ "trt 1").
fn match_channels(tx: &Connection, channels: &[GuideChannel]) -> rusqlite::Result<u64> {
    let mut by_id = tx.prepare("SELECT key FROM xchannel WHERE id = ?1 COLLATE NOCASE")?;
    let mut by_name = tx.prepare("SELECT key FROM xname WHERE name = ?1 LIMIT 1")?;
    let mut put = tx.prepare("INSERT OR REPLACE INTO map (uid, key) VALUES (?1, ?2)")?;
    let mut matched = 0;
    for c in channels {
        let mut key: Option<i64> = None;
        if let Some(id) = c.tvg_id.as_deref().map(str::trim).filter(|i| !i.is_empty()) {
            key = by_id.query_row([id], |r| r.get(0)).ok();
        }
        if key.is_none() {
            let n = match_name(&c.name);
            if !n.is_empty() {
                key = by_name.query_row([n], |r| r.get(0)).ok();
            }
        }
        if let Some(k) = key {
            put.execute(params![c.uid, k])?;
            matched += 1;
        }
    }
    Ok(matched)
}

/// Channel names reduced to what identifies them: no region tag, quality
/// or punctuation. "TR: TRT 1 HD" and "TRT1" both become "trt1".
pub fn match_name(name: &str) -> String {
    let mut s = fold(name);
    // Region / provider tag before a separator.
    if let Some((head, rest)) = s.split_once([':', '|']) {
        if head.trim().len() <= 4 {
            s = rest.to_string();
        }
    }
    const NOISE: &[&str] = &["hd", "fhd", "uhd", "sd", "4k", "8k", "hevc", "h265", "h264", "1080p", "720p", "raw", "backup", "yedek"];
    s.split(|c: char| !c.is_alphanumeric() && c != '+')
        .filter(|w| !w.is_empty() && !NOISE.contains(w))
        .collect::<Vec<_>>()
        .concat()
}

/// A finished guide, read-only.
pub struct Guide {
    conn: Connection,
}

impl Guide {
    pub fn open(path: &Path) -> Result<Option<Guide>> {
        if !path.exists() {
            return Ok(None);
        }
        let conn = Connection::open_with_flags(path, OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX)?;
        Ok(Some(Guide { conn }))
    }

    /// Programmes of playlist channel [uid] overlapping [from]..[to].
    /// [shift] (tvg-shift, seconds) moves the guide's times for this channel.
    pub fn programmes(&self, uid: i64, from: i64, to: i64, shift: i64, limit: u32) -> Result<Vec<EpgRow>> {
        let mut stmt = self.conn.prepare_cached(
            "SELECT p.start, p.stop, p.title, p.descr FROM programme p JOIN map m ON m.key = p.key
             WHERE m.uid = ?1 AND p.stop > ?2 AND p.start < ?3 ORDER BY p.start LIMIT ?4",
        )?;
        let rows = stmt.query_map(params![uid, from - shift, to - shift, limit], |r| {
            Ok(EpgRow {
                start: r.get::<_, i64>(0)? + shift,
                stop: r.get::<_, i64>(1)? + shift,
                title: r.get(2)?,
                description: r.get(3)?,
                archive: false,
            })
        })?;
        Ok(rows.collect::<std::result::Result<_, _>>()?)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn xml(now: i64) -> String {
        let t = |s: i64| chrono::DateTime::from_timestamp(s, 0).unwrap().format("%Y%m%d%H%M%S +0000").to_string();
        format!(
            r#"<tv>
  <channel id="TRT1.tr"><display-name>TRT 1</display-name></channel>
  <channel id="fox.tr"><display-name>FOX</display-name><display-name>NOW</display-name></channel>
  <programme start="{}" stop="{}" channel="trt1.tr"><title>Eski</title></programme>
  <programme start="{}" stop="{}" channel="TRT1.tr"><title>Şimdi</title></programme>
  <programme start="{}" channel="TRT1.tr"><title>Sonra</title></programme>
  <programme start="{}" stop="{}" channel="TRT1.tr"><title>Gece</title></programme>
  <programme start="{}" stop="{}" channel="fox.tr"><title>Dizi</title></programme>
  <programme start="{}" stop="{}" channel="TRT1.tr"><title>Çok eski</title></programme>
</tv>"#,
            t(now - 7200), t(now - 3600),
            t(now - 600), t(now + 1200),
            t(now + 1200),
            t(now + 3600), t(now + 7200),
            t(now - 60), t(now + 60),
            t(now - 30 * 86_400), t(now - 29 * 86_400),
        )
    }

    #[test]
    fn builds_matches_and_reads_a_guide() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("guide-s1.sqlite");
        let now = 1_792_600_000;
        let channels = [
            GuideChannel { uid: 1, tvg_id: Some("trt1.TR".into()), name: "Kanal Bir".into() },
            GuideChannel { uid: 2, tvg_id: None, name: "TR: NOW HD".into() },
            GuideChannel { uid: 3, tvg_id: Some("yok.tr".into()), name: "Bilinmeyen".into() },
        ];
        let stats = build(&path, xml(now).as_bytes(), &channels, now).unwrap();
        assert_eq!(stats, BuildStats { programmes: 5, matched: 2, channels: 3 }, "30-day-old programme dropped");
        install(&path).unwrap();
        assert!(!path.with_extension("sqlite.tmp").exists());

        let g = Guide::open(&path).unwrap().unwrap();
        let trt = g.programmes(1, now, now + 86_400, 0, 10).unwrap();
        let titles: Vec<_> = trt.iter().map(|p| p.title.as_str()).collect();
        assert_eq!(titles, vec!["Şimdi", "Sonra", "Gece"], "tvg-id matched case-insensitively");
        assert_eq!(trt[1].stop, now + 3600, "missing stop filled from the next programme");
        assert_eq!(g.programmes(2, now, now + 86_400, 0, 10).unwrap()[0].title, "Dizi", "matched by display-name");
        assert!(g.programmes(3, now, now + 86_400, 0, 10).unwrap().is_empty());

        // tvg-shift=+1: the guide's times move an hour later for this channel.
        let shifted = g.programmes(1, now, now + 86_400, 3600, 10).unwrap();
        assert_eq!(shifted[0].start, now - 600 + 3600);
        let past = g.programmes(1, now - 86_400, now, 0, 10).unwrap();
        assert_eq!(past[0].title, "Eski");
    }

    #[test]
    fn a_failed_download_keeps_the_old_guide() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("guide-s1.sqlite");
        let now = 1_792_600_000;
        let ch = [GuideChannel { uid: 1, tvg_id: Some("TRT1.tr".into()), name: String::new() }];
        build(&path, xml(now).as_bytes(), &ch, now).unwrap();
        install(&path).unwrap();
        assert!(build(&path, "<html>hata</html>".as_bytes(), &ch, now).is_err());
        assert!(!path.with_extension("sqlite.tmp").exists(), "a failed build leaves nothing behind");
        let g = Guide::open(&path).unwrap().unwrap();
        assert!(!g.programmes(1, now, now + 86_400, 0, 10).unwrap().is_empty());
    }

    #[test]
    fn names_normalize() {
        assert_eq!(match_name("TR: TRT 1 HD"), "trt1");
        assert_eq!(match_name("TRT1"), "trt1");
        assert_eq!(match_name("Show TV 4K"), "showtv");
        assert_eq!(match_name("beIN SPORTS 1 +1"), "beinsports1+1");
    }
}
