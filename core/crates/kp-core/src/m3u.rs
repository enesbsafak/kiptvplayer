//! M3U / M3U8 playlist parsing.
//!
//! Ported from AbiPlayer's `m3u-parser.ts` with three fixes: the title is the
//! text after the first comma *outside quotes* (AbiPlayer took the last comma,
//! which broke titles such as "Haber, Canlı"), the catch-up / tvg-shift /
//! header EPG attributes are kept instead of dropped, and per-entry
//! `#EXTVLCOPT` HTTP options are honoured.

/// One playable entry exactly as the playlist describes it.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct M3uEntry {
    pub title: String,
    pub url: String,
    pub tvg_id: Option<String>,
    pub tvg_name: Option<String>,
    pub tvg_logo: Option<String>,
    pub tvg_chno: Option<String>,
    pub tvg_shift: Option<f32>,
    pub group: Option<String>,
    pub catchup: Option<String>,
    pub catchup_days: Option<u32>,
    pub catchup_source: Option<String>,
    pub user_agent: Option<String>,
    pub referrer: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct M3uPlaylist {
    /// XMLTV URLs announced in the `#EXTM3U` header (`url-tvg` / `x-tvg-url`).
    pub epg_urls: Vec<String>,
    pub entries: Vec<M3uEntry>,
}

pub fn parse(input: &str) -> M3uPlaylist {
    let input = input.strip_prefix('\u{feff}').unwrap_or(input);
    let mut playlist = M3uPlaylist::default();
    let mut pending: Option<M3uEntry> = None;
    let mut pending_group: Option<String> = None;
    let mut vlc_user_agent: Option<String> = None;
    let mut vlc_referrer: Option<String> = None;

    for raw in input.lines() {
        let line = raw.trim();
        if line.is_empty() {
            continue;
        }

        if let Some(rest) = line.strip_prefix("#EXTM3U") {
            for (key, value) in attributes(rest) {
                if key.eq_ignore_ascii_case("url-tvg") || key.eq_ignore_ascii_case("x-tvg-url") {
                    playlist.epg_urls.extend(
                        value.split(',').map(str::trim).filter(|v| !v.is_empty()).map(String::from),
                    );
                }
            }
        } else if let Some(rest) = line.strip_prefix("#EXTINF:") {
            pending = Some(parse_extinf(rest));
        } else if let Some(rest) = line.strip_prefix("#EXTGRP:") {
            pending_group = non_empty(rest.trim());
        } else if let Some(rest) = line.strip_prefix("#EXTVLCOPT:") {
            if let Some((key, value)) = rest.split_once('=') {
                match key.trim().to_ascii_lowercase().as_str() {
                    "http-user-agent" => vlc_user_agent = non_empty(value.trim()),
                    "http-referrer" | "http-referer" => vlc_referrer = non_empty(value.trim()),
                    _ => {}
                }
            }
        } else if line.starts_with('#') {
            // Other directives (#KODIPROP, #EXTBYT, comments) carry nothing we use yet.
        } else {
            let mut entry = pending.take().unwrap_or_else(|| M3uEntry {
                title: name_from_url(line),
                ..M3uEntry::default()
            });
            entry.url = line.to_string();
            if entry.group.is_none() {
                entry.group = pending_group.take();
            }
            entry.user_agent = entry.user_agent.or(vlc_user_agent.take());
            entry.referrer = entry.referrer.or(vlc_referrer.take());
            pending_group = None;
            vlc_user_agent = None;
            vlc_referrer = None;
            playlist.entries.push(entry);
        }
    }

    playlist
}

fn parse_extinf(rest: &str) -> M3uEntry {
    let (attrs_part, title) = split_title(rest);
    let mut entry = M3uEntry { title: title.trim().to_string(), ..M3uEntry::default() };

    for (key, value) in attributes(attrs_part) {
        let value = non_empty(value.trim());
        match key.to_ascii_lowercase().as_str() {
            "tvg-id" => entry.tvg_id = value,
            "tvg-name" => entry.tvg_name = value,
            "tvg-logo" => entry.tvg_logo = value,
            "tvg-chno" | "channel-number" => entry.tvg_chno = value,
            "tvg-shift" => entry.tvg_shift = value.and_then(|v| v.parse().ok()),
            "group-title" => entry.group = value,
            "catchup" | "catchup-type" => entry.catchup = value,
            "catchup-days" | "tvg-rec" | "timeshift" => {
                entry.catchup_days = value.and_then(|v| v.parse().ok())
            }
            "catchup-source" => entry.catchup_source = value,
            "user-agent" | "http-user-agent" => entry.user_agent = value,
            "referrer" | "http-referrer" => entry.referrer = value,
            _ => {}
        }
    }

    if entry.title.is_empty() {
        entry.title = entry.tvg_name.clone().unwrap_or_default();
    }
    entry
}

/// Splits `-1 key="a,b" key2=c,Title, with comma` at the first comma that is
/// not inside double quotes.
fn split_title(rest: &str) -> (&str, &str) {
    let mut in_quotes = false;
    for (i, ch) in rest.char_indices() {
        match ch {
            '"' => in_quotes = !in_quotes,
            ',' if !in_quotes => return (&rest[..i], &rest[i + 1..]),
            _ => {}
        }
    }
    (rest, "")
}

/// Iterates `key="value"` and `key=value` pairs; the leading duration token
/// (`-1`, `0`) has no `=` and is skipped.
fn attributes(s: &str) -> impl Iterator<Item = (&str, &str)> {
    let mut rest = s;
    std::iter::from_fn(move || loop {
        rest = rest.trim_start();
        if rest.is_empty() {
            return None;
        }
        let token_end = rest.find(|c: char| c == '=' || c.is_whitespace()).unwrap_or(rest.len());
        if !rest[token_end..].starts_with('=') {
            rest = &rest[token_end..];
            continue;
        }
        let key = &rest[..token_end];
        let after = &rest[token_end + 1..];
        let (value, remaining) = if let Some(quoted) = after.strip_prefix('"') {
            match quoted.find('"') {
                Some(end) => (&quoted[..end], &quoted[end + 1..]),
                None => (quoted, ""),
            }
        } else {
            let end = after.find(char::is_whitespace).unwrap_or(after.len());
            (&after[..end], &after[end..])
        };
        rest = remaining;
        return Some((key, value));
    })
}

fn name_from_url(url: &str) -> String {
    let without_query = url.split(['?', '#']).next().unwrap_or(url);
    let segment = without_query.trim_end_matches('/').rsplit('/').next().unwrap_or("");
    let stem = match segment.rfind('.') {
        Some(dot) if dot > 0 => &segment[..dot],
        _ => segment,
    };
    if stem.is_empty() { crate::lang::t("Bilinmeyen", "Unknown").to_string() } else { stem.to_string() }
}

fn non_empty(s: &str) -> Option<String> {
    if s.is_empty() { None } else { Some(s.to_string()) }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_extinf_metadata() {
        let p = parse(
            "#EXTM3U\n#EXTINF:-1 tvg-id=\"kanal.tr\" tvg-name=\"Kanal TR\" tvg-logo=\"https://img/logo.png\" group-title=\"Ulusal\",Kanal TR HD\nhttps://cdn.example.com/live/kanal.m3u8\n",
        );
        assert_eq!(p.entries.len(), 1);
        let e = &p.entries[0];
        assert_eq!(e.title, "Kanal TR HD");
        assert_eq!(e.tvg_id.as_deref(), Some("kanal.tr"));
        assert_eq!(e.tvg_logo.as_deref(), Some("https://img/logo.png"));
        assert_eq!(e.group.as_deref(), Some("Ulusal"));
        assert_eq!(e.url, "https://cdn.example.com/live/kanal.m3u8");
    }

    #[test]
    fn title_keeps_commas_and_quoted_attribute_commas_are_ignored() {
        let p = parse("#EXTINF:-1 group-title=\"Haber, Ulusal\",Haber, Canlı\nhttp://a/1.ts\n");
        assert_eq!(p.entries[0].group.as_deref(), Some("Haber, Ulusal"));
        assert_eq!(p.entries[0].title, "Haber, Canlı");
    }

    #[test]
    fn parses_unquoted_attributes() {
        let p = parse("#EXTINF:-1 tvg-id=kanal.tr tvg-logo=https://img.png group-title=Spor,Test Kanal\nhttps://s/live.m3u8");
        let e = &p.entries[0];
        assert_eq!(e.tvg_id.as_deref(), Some("kanal.tr"));
        assert_eq!(e.tvg_logo.as_deref(), Some("https://img.png"));
        assert_eq!(e.group.as_deref(), Some("Spor"));
        assert_eq!(e.title, "Test Kanal");
    }

    #[test]
    fn extgrp_bare_urls_and_bom() {
        let p = parse("\u{feff}#EXTM3U\n#EXTINF:-1,Kanal 1\n#EXTGRP:Ulusal\nhttps://s/1.m3u8\nhttps://cdn/simple/live.m3u8?token=x\n");
        assert_eq!(p.entries[0].group.as_deref(), Some("Ulusal"));
        assert_eq!(p.entries[1].title, "live");
        assert_eq!(p.entries[1].group, None);
    }

    #[test]
    fn header_epg_catchup_and_vlcopt() {
        let p = parse(
            "#EXTM3U url-tvg=\"http://e/1.xml.gz,http://e/2.xml\" x-tvg-url=\"http://e/3.xml\"\n\
             #EXTINF:-1 catchup=\"shift\" catchup-days=\"7\" tvg-shift=\"+2\" tvg-chno=\"101\",A\n\
             #EXTVLCOPT:http-user-agent=KaradelikTest/1.0\n\
             #EXTVLCOPT:http-referrer=http://ref/\n\
             http://s/a.ts\n\
             #EXTINF:-1,B\nhttp://s/b.ts\n",
        );
        assert_eq!(p.epg_urls, vec!["http://e/1.xml.gz", "http://e/2.xml", "http://e/3.xml"]);
        let a = &p.entries[0];
        assert_eq!(a.catchup.as_deref(), Some("shift"));
        assert_eq!(a.catchup_days, Some(7));
        assert_eq!(a.tvg_shift, Some(2.0));
        assert_eq!(a.tvg_chno.as_deref(), Some("101"));
        assert_eq!(a.user_agent.as_deref(), Some("KaradelikTest/1.0"));
        assert_eq!(a.referrer.as_deref(), Some("http://ref/"));
        // VLC options apply to the next URL only.
        assert_eq!(p.entries[1].user_agent, None);
    }

    #[test]
    fn falls_back_to_tvg_name_for_empty_title() {
        let p = parse("#EXTINF:-1 tvg-name=\"Yedek Ad\",\nhttp://s/x.ts");
        assert_eq!(p.entries[0].title, "Yedek Ad");
    }
}
