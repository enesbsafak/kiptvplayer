//! Source-independent catalog records built from parsed playlists.

use std::collections::HashMap;

use xxhash_rust::xxh3::xxh3_64;

use crate::adult::is_adult_label;
use crate::region::detect_region;
use crate::m3u::{M3uEntry, M3uPlaylist};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum ContentKind {
    Live = 0,
    Movie = 1,
    Series = 2,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CategoryRecord {
    /// Stable across refreshes of the same source.
    pub uid: i64,
    pub name: String,
    pub kind: ContentKind,
    pub adult: bool,
    /// Provider order, which users expect to see preserved.
    pub sort: u32,
    /// Region code read from the name (`TR: Ulusal` → TR), if any.
    pub region: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ChannelRecord {
    /// Stable across refreshes: favourites and watch history key on it.
    pub uid: i64,
    pub category_uid: Option<i64>,
    pub name: String,
    pub logo: Option<String>,
    pub url: String,
    pub kind: ContentKind,
    pub tvg_id: Option<String>,
    pub chno: Option<u32>,
    pub adult: bool,
    pub sort: u32,
    pub catchup: Option<String>,
    pub catchup_days: Option<u32>,
    pub catchup_source: Option<String>,
    pub tvg_shift: Option<f32>,
    pub user_agent: Option<String>,
    pub referrer: Option<String>,
    /// Provider id (Xtream stream_id / series_id); None for M3U.
    pub ext_id: Option<i64>,
    /// File extension for VOD / series playback (mp4, mkv...).
    pub container: Option<String>,
    /// 0-10 scale.
    pub rating: Option<f32>,
    pub year: Option<i32>,
    /// Unix seconds the provider added the item.
    pub added: Option<i64>,
    /// The category's region, or one read from the item's own name.
    pub region: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct Catalog {
    pub categories: Vec<CategoryRecord>,
    pub channels: Vec<ChannelRecord>,
    pub epg_urls: Vec<String>,
}

const VOD_EXTENSIONS: &[&str] = &["mp4", "mkv", "avi", "mov", "wmv", "flv"];

impl Catalog {
    pub fn from_m3u(playlist: M3uPlaylist) -> Self {
        let mut group_order: Vec<String> = Vec::new();
        let mut group_entries: HashMap<&str, Vec<&M3uEntry>> = HashMap::new();
        for entry in &playlist.entries {
            if let Some(group) = entry.group.as_deref() {
                let list = group_entries.entry(group).or_default();
                if list.is_empty() {
                    group_order.push(group.to_string());
                }
                list.push(entry);
            }
        }

        let mut categories = Vec::with_capacity(group_order.len());
        let mut group_meta: HashMap<&str, (i64, ContentKind, bool, Option<String>)> = HashMap::new();
        for (sort, name) in group_order.iter().enumerate() {
            let kind = detect_group_kind(name, &group_entries[name.as_str()]);
            let uid = hash_uid(&["grp", name]);
            let adult = is_adult_label(name);
            let region = detect_region(name).map(String::from);
            categories.push(CategoryRecord { uid, name: name.clone(), kind, adult, sort: sort as u32, region: region.clone() });
            group_meta.insert(name.as_str(), (uid, kind, adult, region));
        }

        // The same stream often appears in several groups, and some playlists
        // repeat an identical line. Uids must stay unique and stable, so an
        // exact repeat gets an occurrence counter mixed in.
        let mut seen: HashMap<i64, u32> = HashMap::new();
        let mut channels = Vec::with_capacity(playlist.entries.len());
        for (sort, entry) in playlist.entries.iter().enumerate() {
            let group = entry.group.as_deref().unwrap_or("");
            let base = hash_uid(&["ch", &entry.url, group, &entry.title]);
            let n = seen.entry(base).or_insert(0);
            let uid = if *n == 0 { base } else { hash_uid(&["ch", &entry.url, group, &entry.title, &n.to_string()]) };
            *n += 1;

            let meta = entry.group.as_deref().and_then(|g| group_meta.get(g)).cloned();
            let name = if entry.title.is_empty() { crate::lang::t("Bilinmeyen", "Unknown").to_string() } else { entry.title.clone() };
            channels.push(ChannelRecord {
                uid,
                category_uid: meta.as_ref().map(|m| m.0),
                kind: meta.as_ref().map(|m| m.1).unwrap_or_else(|| detect_url_kind(&entry.url)),
                adult: meta.as_ref().map(|m| m.2).unwrap_or(false) || is_adult_label(&name),
                region: meta.and_then(|m| m.3).or_else(|| detect_region(&name).map(String::from)),
                name,
                logo: entry.tvg_logo.clone(),
                url: entry.url.clone(),
                tvg_id: entry.tvg_id.clone(),
                chno: entry.tvg_chno.as_deref().and_then(|c| c.parse().ok()),
                sort: sort as u32,
                catchup: entry.catchup.clone(),
                catchup_days: entry.catchup_days,
                catchup_source: entry.catchup_source.clone(),
                tvg_shift: entry.tvg_shift,
                user_agent: entry.user_agent.clone(),
                referrer: entry.referrer.clone(),
                ext_id: None,
                container: None,
                rating: None,
                year: None,
                added: None,
            });
        }

        Catalog { categories, channels, epg_urls: playlist.epg_urls }
    }
}

/// Raw Xtream lists for one content kind, as returned by the panel.
pub struct XtreamLists {
    pub kind: ContentKind,
    pub categories: Vec<serde_json::Value>,
    pub items: Vec<serde_json::Value>,
}

impl Catalog {
    /// Builds the catalog from Xtream lists. Stream URLs are *not* stored:
    /// they embed the password, so they are built at playback time from the
    /// OS credential store. `url` holds a `xtream:<kind>:<id>` marker instead.
    pub fn from_xtream(lists: Vec<XtreamLists>) -> Self {
        use crate::xtream::{as_f32, as_i64, as_string};

        let mut catalog = Catalog::default();
        let mut sort = 0u32;
        for list in lists {
            let prefix = match list.kind {
                ContentKind::Live => "live",
                ContentKind::Movie => "movie",
                ContentKind::Series => "series",
            };
            let mut adult_cats: HashMap<String, (i64, bool, Option<&'static str>)> = HashMap::new();
            for (i, c) in list.categories.iter().enumerate() {
                let Some(id) = as_string(c.get("category_id")) else { continue };
                let name = as_string(c.get("category_name")).unwrap_or_else(|| id.clone());
                let uid = hash_uid(&["xcat", prefix, &id]);
                let adult = is_adult_label(&name);
                let region = detect_region(&name);
                adult_cats.insert(id, (uid, adult, region));
                catalog.categories.push(CategoryRecord {
                    uid,
                    name,
                    kind: list.kind,
                    adult,
                    sort: i as u32,
                    region: region.map(String::from),
                });
            }

            for item in &list.items {
                let id_field = if list.kind == ContentKind::Series { "series_id" } else { "stream_id" };
                let Some(ext_id) = as_i64(item.get(id_field)) else { continue };
                let name = as_string(item.get("name")).unwrap_or_else(|| crate::lang::t("Bilinmeyen", "Unknown").to_string());
                let cat = as_string(item.get("category_id")).and_then(|c| adult_cats.get(&c).copied());
                let poster_key = if list.kind == ContentKind::Series { "cover" } else { "stream_icon" };
                let archive = list.kind == ContentKind::Live && as_i64(item.get("tv_archive")) == Some(1);
                let rating = as_f32(item.get("rating"))
                    .filter(|r| *r > 0.0)
                    .or_else(|| as_f32(item.get("rating_5based")).map(|r| r * 2.0))
                    .filter(|r| *r > 0.0);
                let year = as_string(item.get("year"))
                    .or_else(|| as_string(item.get("releaseDate")))
                    .or_else(|| as_string(item.get("release_date")))
                    .and_then(|d| d.get(..4).and_then(|y| y.parse().ok()));

                catalog.channels.push(ChannelRecord {
                    uid: hash_uid(&["x", prefix, &ext_id.to_string()]),
                    category_uid: cat.map(|c| c.0),
                    adult: cat.map(|c| c.1).unwrap_or(false)
                        || as_i64(item.get("is_adult")) == Some(1)
                        || is_adult_label(&name),
                    logo: as_string(item.get(poster_key)),
                    url: format!("xtream:{prefix}:{ext_id}"),
                    kind: list.kind,
                    tvg_id: as_string(item.get("epg_channel_id")),
                    chno: as_i64(item.get("num")).and_then(|n| u32::try_from(n).ok()),
                    sort,
                    catchup: archive.then(|| "xc".to_string()),
                    catchup_days: if archive { as_i64(item.get("tv_archive_duration")).map(|d| d as u32) } else { None },
                    catchup_source: None,
                    tvg_shift: None,
                    user_agent: None,
                    referrer: None,
                    ext_id: Some(ext_id),
                    container: as_string(item.get("container_extension")),
                    rating,
                    year,
                    added: as_i64(item.get("added")).or_else(|| as_i64(item.get("last_modified"))),
                    region: cat.and_then(|c| c.2).or_else(|| detect_region(&name)).map(String::from),
                    name,
                });
                sort += 1;
            }
        }
        catalog
    }
}

impl Catalog {
    /// Builds the catalog from a Stalker portal's live genres and channels.
    /// Links expire, so `url` keeps the channel's play command
    /// (`stalker:<cmd>`), turned into a link when playback starts.
    pub fn from_stalker(
        genres: &[crate::stalker::Genre],
        channels: &[crate::stalker::Channel],
        vod_categories: &[crate::stalker::Genre],
        movies: &[crate::stalker::Movie],
    ) -> Self {
        let mut catalog = Catalog::default();
        let mut meta: HashMap<&str, (i64, bool, Option<&'static str>)> = HashMap::new();
        for (i, g) in genres.iter().enumerate() {
            let uid = hash_uid(&["scat", &g.id]);
            let adult = is_adult_label(&g.title);
            let region = detect_region(&g.title);
            meta.insert(g.id.as_str(), (uid, adult, region));
            catalog.categories.push(CategoryRecord {
                uid,
                name: g.title.clone(),
                kind: ContentKind::Live,
                adult,
                sort: i as u32,
                region: region.map(String::from),
            });
        }
        for (sort, c) in channels.iter().enumerate() {
            let cat = c.genre_id.as_deref().and_then(|g| meta.get(g).copied());
            catalog.channels.push(ChannelRecord {
                uid: hash_uid(&["s", &c.id.to_string()]),
                category_uid: cat.map(|m| m.0),
                adult: c.adult || cat.is_some_and(|m| m.1) || is_adult_label(&c.name),
                logo: c.logo.clone(),
                url: format!("stalker:{}", c.cmd),
                kind: ContentKind::Live,
                tvg_id: None,
                chno: c.number,
                sort: sort as u32,
                catchup: None,
                catchup_days: None,
                catchup_source: None,
                tvg_shift: None,
                user_agent: None,
                referrer: None,
                ext_id: Some(c.id),
                container: None,
                rating: None,
                year: None,
                added: None,
                region: cat.and_then(|m| m.2).or_else(|| detect_region(&c.name)).map(String::from),
                name: c.name.clone(),
            });
        }
        // Films: `stalker-vod:<cmd>`, a link asked for at playback like live.
        let mut vod_meta: HashMap<&str, (i64, bool, Option<&'static str>)> = HashMap::new();
        for (i, g) in vod_categories.iter().enumerate() {
            let uid = hash_uid(&["svcat", &g.id]);
            let adult = is_adult_label(&g.title);
            let region = detect_region(&g.title);
            vod_meta.insert(g.id.as_str(), (uid, adult, region));
            catalog.categories.push(CategoryRecord {
                uid,
                name: g.title.clone(),
                kind: ContentKind::Movie,
                adult,
                sort: i as u32,
                region: region.map(String::from),
            });
        }
        let base = channels.len() as u32;
        for (i, m) in movies.iter().enumerate() {
            let cat = vod_meta.get(m.category_id.as_str()).copied();
            catalog.channels.push(ChannelRecord {
                uid: hash_uid(&["sv", &m.id.to_string()]),
                category_uid: cat.map(|c| c.0),
                adult: m.adult || cat.is_some_and(|c| c.1) || is_adult_label(&m.name),
                logo: m.poster.clone(),
                url: format!("stalker-vod:{}", m.cmd),
                kind: ContentKind::Movie,
                tvg_id: None,
                chno: None,
                sort: base + i as u32,
                catchup: None,
                catchup_days: None,
                catchup_source: None,
                tvg_shift: None,
                user_agent: None,
                referrer: None,
                ext_id: Some(m.id),
                container: None,
                rating: m.rating,
                year: m.year,
                added: None,
                region: cat.and_then(|c| c.2).or_else(|| detect_region(&m.name)).map(String::from),
                name: m.name.clone(),
            });
        }
        catalog
    }
}

/// 64-bit stable id. AbiPlayer used a 32-bit string hash and silently dropped
/// colliding channels; at 100k entries a 32-bit space collides routinely.
fn hash_uid(parts: &[&str]) -> i64 {
    let mut buf = String::new();
    for part in parts {
        buf.push_str(part);
        buf.push('\u{1f}');
    }
    xxh3_64(buf.as_bytes()) as i64
}

fn has_word(haystack: &str, words: &[&str]) -> bool {
    haystack
        .split(|c: char| !c.is_alphanumeric())
        .any(|w| words.contains(&w))
}

fn detect_group_kind(name: &str, entries: &[&M3uEntry]) -> ContentKind {
    let lower = crate::text::fold(name);
    if has_word(&lower, &["series", "serie", "dizi", "diziler", "sezon", "season"]) {
        return ContentKind::Series;
    }
    if has_word(&lower, &["vod", "movie", "movies", "film", "films", "filmler", "sinema", "cinema"]) {
        return ContentKind::Movie;
    }
    if entries.iter().any(|e| e.url.to_ascii_lowercase().contains("/series/")) {
        return ContentKind::Series;
    }
    if entries.iter().any(|e| e.url.to_ascii_lowercase().contains("/movie/")) {
        return ContentKind::Movie;
    }
    let vod = entries.iter().filter(|e| has_vod_extension(&e.url)).count();
    if vod * 2 > entries.len() { ContentKind::Movie } else { ContentKind::Live }
}

fn detect_url_kind(url: &str) -> ContentKind {
    let lower = url.to_ascii_lowercase();
    if lower.contains("/series/") {
        ContentKind::Series
    } else if lower.contains("/movie/") || has_vod_extension(url) {
        ContentKind::Movie
    } else {
        ContentKind::Live
    }
}

fn has_vod_extension(url: &str) -> bool {
    let path = url.split(['?', '#']).next().unwrap_or(url);
    path.rsplit_once('.')
        .map(|(_, ext)| VOD_EXTENSIONS.contains(&ext.to_ascii_lowercase().as_str()))
        .unwrap_or(false)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::m3u::parse;

    #[test]
    fn builds_categories_in_provider_order_with_kinds() {
        let c = Catalog::from_m3u(parse(
            "#EXTINF:-1 group-title=\"Ulusal\",Kanal TR HD\nhttps://c/live/kanal.m3u8\n\
             #EXTINF:-1 group-title=\"Filmler\",Aksiyon Gecesi\nhttps://c/media/movie.mp4\n\
             #EXTINF:-1 group-title=\"Diziler\",Bölüm 1\nhttps://c/x/1.mkv\n",
        ));
        let names: Vec<_> = c.categories.iter().map(|c| (c.name.as_str(), c.kind)).collect();
        assert_eq!(names, vec![("Ulusal", ContentKind::Live), ("Filmler", ContentKind::Movie), ("Diziler", ContentKind::Series)]);
        assert_eq!(c.channels[0].category_uid, Some(c.categories[0].uid));
    }

    #[test]
    fn uids_are_stable_and_unique_for_repeated_lines() {
        let text = "#EXTINF:-1 group-title=\"Spor\",Kanal 1\nhttp://a/1.m3u8\n#EXTINF:-1 group-title=\"Spor\",Kanal 1\nhttp://a/1.m3u8\n#EXTINF:-1 group-title=\"Ulusal\",Kanal 1\nhttp://a/1.m3u8\n";
        let a = Catalog::from_m3u(parse(text));
        let b = Catalog::from_m3u(parse(text));
        assert_eq!(a.channels.len(), 3);
        let uids: std::collections::HashSet<_> = a.channels.iter().map(|c| c.uid).collect();
        assert_eq!(uids.len(), 3);
        assert_eq!(a.channels.iter().map(|c| c.uid).collect::<Vec<_>>(), b.channels.iter().map(|c| c.uid).collect::<Vec<_>>());
    }

    #[test]
    fn xtream_lists_become_catalog_without_credentials() {
        use serde_json::json;
        let c = Catalog::from_xtream(vec![
            XtreamLists {
                kind: ContentKind::Live,
                categories: vec![json!({"category_id": "1", "category_name": "Ulusal"}), json!({"category_id": 9, "category_name": "XXX"})],
                items: vec![
                    json!({"stream_id": "101", "name": "TRT 1", "category_id": "1", "num": 1, "epg_channel_id": "trt1.tr", "tv_archive": 1, "tv_archive_duration": "3"}),
                    json!({"stream_id": 102, "name": "Kanal X", "category_id": "9"}),
                    json!({"name": "id yok"}),
                ],
            },
            XtreamLists {
                kind: ContentKind::Movie,
                categories: vec![],
                items: vec![json!({"stream_id": 5, "name": "Film", "rating_5based": 4, "container_extension": "mkv", "year": "2021"})],
            },
        ]);
        assert_eq!(c.categories.len(), 2);
        assert_eq!(c.channels.len(), 3, "item without an id is skipped");
        let trt = &c.channels[0];
        assert_eq!(trt.url, "xtream:live:101");
        assert_eq!((trt.catchup.as_deref(), trt.catchup_days, trt.chno), (Some("xc"), Some(3), Some(1)));
        assert!(c.channels[1].adult, "adult via category name");
        let film = &c.channels[2];
        assert_eq!((film.kind, film.rating, film.year, film.container.as_deref()), (ContentKind::Movie, Some(8.0), Some(2021), Some("mkv")));
    }

    #[test]
    fn adult_flag_from_group_or_name() {
        let c = Catalog::from_m3u(parse(
            "#EXTINF:-1 group-title=\"XXX\",Kanal A\nhttps://a/1.m3u8\n#EXTINF:-1 group-title=\"Yetişkin\",Kanal B\nhttps://a/2.m3u8\n#EXTINF:-1 group-title=\"Ulusal\",Brazzers TV\nhttps://a/3.m3u8\n#EXTINF:-1 group-title=\"Ulusal\",Haber TV\nhttps://a/4.m3u8\n",
        ));
        let flags: Vec<_> = c.channels.iter().map(|c| c.adult).collect();
        assert_eq!(flags, vec![true, true, true, false]);
    }
}
