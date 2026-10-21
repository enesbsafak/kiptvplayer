//! OpenSubtitles.com: subtitle search and download with the user's own API
//! key (kept in the OS credential store). Search goes by TMDB id when the
//! film or series is matched, else by its cleaned title and year.

use std::path::{Path, PathBuf};
use std::time::Duration;

use serde_json::Value;

use crate::xtream::{as_i64, as_string};

pub const DEFAULT_BASE: &str = "https://api.opensubtitles.com/api/v1";

#[derive(Debug, thiserror::Error)]
pub enum OpenSubsError {
    #[error("network: {0}")]
    Network(String),
    #[error("the API key was refused")]
    BadKey,
    #[error("download limit reached")]
    Limit,
    #[error("HTTP {0}")]
    Status(u16),
    #[error("unexpected response")]
    BadResponse,
}

pub type Result<T> = std::result::Result<T, OpenSubsError>;

/// What to find subtitles for.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct SubQuery {
    /// The film, or the series' episode: TMDB ids when known.
    pub tmdb_id: Option<i64>,
    pub parent_tmdb_id: Option<i64>,
    pub query: Option<String>,
    pub year: Option<i32>,
    pub season: Option<i32>,
    pub episode: Option<i32>,
    /// "tr,en".
    pub languages: String,
}

/// One downloadable subtitle file.
#[derive(Debug, Clone, PartialEq)]
pub struct SubResult {
    pub file_id: i64,
    pub language: String,
    pub release: String,
    pub file_name: String,
    pub downloads: i64,
    pub hearing_impaired: bool,
    /// Machine or AI translated.
    pub machine: bool,
    pub trusted: bool,
}

pub struct OpenSubs {
    base: String,
    key: String,
    http: reqwest::blocking::Client,
}

impl OpenSubs {
    pub fn new(key: &str, base: Option<&str>, app_version: &str) -> Result<Self> {
        let http = crate::net::client()
            .timeout(Duration::from_secs(20))
            .connect_timeout(Duration::from_secs(10))
            // The API asks every client to name itself.
            .user_agent(format!("Karadelik IPTV Player v{app_version}"))
            .build()
            .map_err(|e| OpenSubsError::Network(e.to_string()))?;
        Ok(OpenSubs { base: base.unwrap_or(DEFAULT_BASE).trim_end_matches('/').to_string(), key: key.trim().to_string(), http })
    }

    fn check(resp: reqwest::blocking::Response) -> Result<Value> {
        match resp.status().as_u16() {
            200..=299 => resp.json().map_err(|_| OpenSubsError::BadResponse),
            401 | 403 => Err(OpenSubsError::BadKey),
            406 | 429 => Err(OpenSubsError::Limit),
            s => Err(OpenSubsError::Status(s)),
        }
    }

    /// A cheap call that needs a valid key.
    pub fn validate(&self) -> Result<()> {
        let resp = self
            .http
            .get(format!("{}/infos/formats", self.base))
            .header("Api-Key", &self.key)
            .send()
            .map_err(|e| OpenSubsError::Network(e.to_string()))?;
        Self::check(resp).map(|_| ())
    }

    pub fn search(&self, q: &SubQuery) -> Result<Vec<SubResult>> {
        let mut params: Vec<(&str, String)> = vec![("languages", q.languages.clone())];
        let num = |v: Option<i64>| v.map(|n| n.to_string());
        if let Some(id) = num(q.tmdb_id) {
            params.push(("tmdb_id", id));
        }
        if let Some(id) = num(q.parent_tmdb_id) {
            params.push(("parent_tmdb_id", id));
        }
        if q.tmdb_id.is_none() && q.parent_tmdb_id.is_none() {
            if let Some(text) = &q.query {
                params.push(("query", text.clone()));
            }
            if let Some(y) = q.year {
                params.push(("year", y.to_string()));
            }
        }
        if let (Some(s), Some(e)) = (q.season, q.episode) {
            params.push(("season_number", s.to_string()));
            params.push(("episode_number", e.to_string()));
            params.push(("type", "episode".into()));
        } else {
            params.push(("type", "movie".into()));
        }
        // The API wants its parameters sorted (it redirects otherwise).
        params.sort_by(|a, b| a.0.cmp(b.0));
        let resp = self
            .http
            .get(format!("{}/subtitles", self.base))
            .header("Api-Key", &self.key)
            .query(&params)
            .send()
            .map_err(|e| OpenSubsError::Network(e.to_string()))?;
        let v = Self::check(resp)?;
        Ok(parse_search(&v))
    }

    /// Fetches [file_id] into [dir]; returns the file and the downloads left today.
    pub fn download(&self, file_id: i64, dir: &Path) -> Result<(PathBuf, Option<i64>)> {
        let resp = self
            .http
            .post(format!("{}/download", self.base))
            .header("Api-Key", &self.key)
            .json(&serde_json::json!({ "file_id": file_id }))
            .send()
            .map_err(|e| OpenSubsError::Network(e.to_string()))?;
        let v = Self::check(resp)?;
        let link = as_string(v.get("link")).ok_or(OpenSubsError::BadResponse)?;
        let name = as_string(v.get("file_name")).unwrap_or_else(|| format!("{file_id}.srt"));
        // Only a plain file name from the server, never a path.
        let safe: String = name.chars().map(|c| if c.is_alphanumeric() || ".-_ ".contains(c) { c } else { '_' }).collect();
        let bytes = self
            .http
            .get(&link)
            .send()
            .and_then(|r| r.error_for_status())
            .and_then(|r| r.bytes())
            .map_err(|e| OpenSubsError::Network(e.to_string()))?;
        std::fs::create_dir_all(dir).map_err(|e| OpenSubsError::Network(e.to_string()))?;
        let path = dir.join(format!("{file_id}-{safe}"));
        std::fs::write(&path, &bytes).map_err(|e| OpenSubsError::Network(e.to_string()))?;
        Ok((path, as_i64(v.get("remaining"))))
    }
}

/// Search results, most downloaded first, one row per file.
fn parse_search(v: &Value) -> Vec<SubResult> {
    let mut out = Vec::new();
    for item in v.get("data").and_then(Value::as_array).into_iter().flatten() {
        let a = &item["attributes"];
        let flag = |k: &str| a.get(k).and_then(Value::as_bool).unwrap_or(false);
        for f in a.get("files").and_then(Value::as_array).into_iter().flatten() {
            let Some(file_id) = as_i64(f.get("file_id")) else { continue };
            out.push(SubResult {
                file_id,
                language: as_string(a.get("language")).unwrap_or_default(),
                release: as_string(a.get("release")).unwrap_or_default(),
                file_name: as_string(f.get("file_name")).unwrap_or_default(),
                downloads: as_i64(a.get("download_count")).unwrap_or(0),
                hearing_impaired: flag("hearing_impaired"),
                machine: flag("machine_translated") || flag("ai_translated"),
                trusted: flag("from_trusted"),
            });
        }
    }
    out.sort_by(|a, b| b.downloads.cmp(&a.downloads));
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn search_results_flatten_files_and_sort_by_downloads() {
        let v = serde_json::json!({ "data": [
            { "attributes": { "language": "en", "release": "Film.2020.1080p", "download_count": 10,
                "hearing_impaired": true, "files": [{ "file_id": 1, "file_name": "a.srt" }] } },
            { "attributes": { "language": "tr", "release": "Film.2020.WEB", "download_count": 900,
                "ai_translated": true, "files": [{ "file_id": 2, "file_name": "b.srt" }, { "file_id": 3, "file_name": "c.srt" }] } }
        ]});
        let r = parse_search(&v);
        assert_eq!(r.iter().map(|s| s.file_id).collect::<Vec<_>>(), [2, 3, 1]);
        assert!(r[0].machine && r[2].hearing_impaired && r[0].language == "tr");
    }
}
