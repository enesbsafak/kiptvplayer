//! Catch-up (archive) URLs for M3U sources.
//!
//! Covers the catch-up types players agree on (Kodi's pvr.iptvsimple is the
//! reference): `default` (full template URL), `append` (template appended to
//! the stream URL), `shift` (`utc` / `lutc` query parameters) and
//! `flussonic` (path rewrite). Xtream catch-up has its own URL form and is
//! built by `XtreamClient::timeshift_url`.

use chrono::{DateTime, Datelike, Local, TimeZone, Timelike, Utc};

/// Builds the archive URL for a programme that ran from [start] to [stop]
/// (Unix seconds). Returns `None` when the type is unknown or incomplete.
pub fn catchup_url(kind: &str, stream_url: &str, source: Option<&str>, start: i64, stop: i64, now: i64) -> Option<String> {
    let duration = (stop - start).max(0);
    match kind.to_ascii_lowercase().as_str() {
        "shift" | "timeshift" => {
            let sep = if stream_url.contains('?') { '&' } else { '?' };
            Some(format!("{stream_url}{sep}utc={start}&lutc={now}"))
        }
        "append" => {
            let template = source?;
            Some(format!("{stream_url}{}", expand(template, start, stop, now)))
        }
        "default" => match source {
            Some(template) if !template.trim().is_empty() => Some(expand(template, start, stop, now)),
            _ => None,
        },
        "flussonic" | "flussonic-hls" | "flussonic-ts" | "fs" => flussonic(stream_url, start, duration),
        _ => None,
    }
}

/// Flussonic: `/name/index.m3u8` → `/name/index-<start>-<duration>.m3u8`,
/// `/name/mpegts` → `/name/timeshift_abs-<start>.ts`.
fn flussonic(url: &str, start: i64, duration: i64) -> Option<String> {
    let (base, query) = match url.split_once('?') {
        Some((b, q)) => (b, format!("?{q}")),
        None => (url, String::new()),
    };
    let (dir, file) = base.rsplit_once('/')?;
    let path = if file == "mpegts" {
        format!("{dir}/timeshift_abs-{start}.ts")
    } else if let Some(name) = file.strip_suffix(".m3u8") {
        let name = if name == "mono" || name == "video" || name == "index" { name } else { "index" };
        format!("{dir}/{name}-{start}-{duration}.m3u8")
    } else {
        return None;
    };
    Some(format!("{path}{query}"))
}

/// Replaces the placeholders players use in catch-up templates.
pub fn expand(template: &str, start: i64, stop: i64, now: i64) -> String {
    let duration = (stop - start).max(0);
    let local: DateTime<Local> = Local.timestamp_opt(start, 0).single().unwrap_or_else(|| Utc::now().with_timezone(&Local));
    let mut out = template.to_string();

    // {duration:N} → duration divided by N (e.g. minutes with N = 60).
    while let Some(i) = out.find("{duration:") {
        let Some(len) = out[i..].find('}') else { break };
        let divisor: i64 = out[i + 10..i + len].parse().unwrap_or(1).max(1);
        out.replace_range(i..i + len + 1, &(duration / divisor).to_string());
    }

    let pairs: [(&str, String); 22] = [
        ("${start}", start.to_string()),
        ("${end}", stop.to_string()),
        ("${timestamp}", now.to_string()),
        ("${now}", now.to_string()),
        ("${duration}", duration.to_string()),
        ("${offset}", (now - start).to_string()),
        ("{utcend}", stop.to_string()),
        ("{utc}", start.to_string()),
        ("{start}", start.to_string()),
        ("{end}", stop.to_string()),
        ("{lutc}", now.to_string()),
        ("{now}", now.to_string()),
        ("{timestamp}", now.to_string()),
        ("{duration}", duration.to_string()),
        ("{offset}", (now - start).to_string()),
        ("{Y}", format!("{:04}", local.year())),
        ("{m}", format!("{:02}", local.month())),
        ("{d}", format!("{:02}", local.day())),
        ("{H}", format!("{:02}", local.hour())),
        ("{M}", format!("{:02}", local.minute())),
        ("{S}", format!("{:02}", local.second())),
        ("{y}", format!("{:02}", local.year() % 100)),
    ];
    for (key, value) in pairs {
        out = out.replace(key, &value);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    const START: i64 = 1_792_000_000;
    const STOP: i64 = START + 3600;
    const NOW: i64 = START + 7200;

    #[test]
    fn shift_adds_utc_parameters() {
        assert_eq!(
            catchup_url("shift", "http://h/live/1.ts", None, START, STOP, NOW).unwrap(),
            format!("http://h/live/1.ts?utc={START}&lutc={NOW}")
        );
        assert_eq!(
            catchup_url("shift", "http://h/live/1.ts?token=x", None, START, STOP, NOW).unwrap(),
            format!("http://h/live/1.ts?token=x&utc={START}&lutc={NOW}")
        );
    }

    #[test]
    fn append_and_default_expand_templates() {
        assert_eq!(
            catchup_url("append", "http://h/ch.m3u8", Some("?utc={utc}&lutc={lutc}"), START, STOP, NOW).unwrap(),
            format!("http://h/ch.m3u8?utc={START}&lutc={NOW}")
        );
        assert_eq!(
            catchup_url("default", "http://h/ch.m3u8", Some("http://h/arc/${start}-${duration}.ts"), START, STOP, NOW).unwrap(),
            format!("http://h/arc/{START}-3600.ts")
        );
        assert_eq!(expand("{duration:60}min", START, STOP, NOW), "60min");
        assert!(catchup_url("default", "http://h/ch.m3u8", None, START, STOP, NOW).is_none());
    }

    #[test]
    fn flussonic_rewrites_the_path() {
        assert_eq!(
            catchup_url("flussonic", "http://h/trt1/index.m3u8?token=t", None, START, STOP, NOW).unwrap(),
            format!("http://h/trt1/index-{START}-3600.m3u8?token=t")
        );
        assert_eq!(
            catchup_url("flussonic", "http://h/trt1/mpegts", None, START, STOP, NOW).unwrap(),
            format!("http://h/trt1/timeshift_abs-{START}.ts")
        );
    }

    #[test]
    fn unknown_type_is_none() {
        assert!(catchup_url("vod", "http://h/1.ts", None, START, STOP, NOW).is_none());
    }
}
