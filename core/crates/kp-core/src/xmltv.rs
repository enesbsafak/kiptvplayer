//! Streaming XMLTV reader. Guides run to hundreds of megabytes, so nothing
//! is held in memory: channels and programmes are handed out one at a time
//! as the (optionally gzipped) bytes arrive.

use std::io::{BufRead, BufReader, Read};

use chrono::{FixedOffset, NaiveDateTime, TimeZone};
use quick_xml::events::{BytesStart, Event};
use quick_xml::Reader;

#[derive(Debug, Clone, PartialEq)]
pub struct XChannel {
    pub id: String,
    pub names: Vec<String>,
    pub icon: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct XProgramme {
    pub channel: String,
    /// Unix seconds (UTC).
    pub start: i64,
    pub stop: i64,
    pub title: String,
    pub description: String,
}

#[derive(Debug, Default, Clone, Copy, PartialEq)]
pub struct Stats {
    pub channels: u64,
    pub programmes: u64,
    /// Programmes skipped for missing or unreadable times.
    pub skipped: u64,
}

#[derive(Debug, thiserror::Error)]
pub enum XmltvError {
    #[error("{}: {}", crate::lang::t("yayın akışı okunamadı", "could not read the TV guide"), .0)]
    Read(String),
    #[error("{}", crate::lang::t("yayın akışı XMLTV biçiminde değil", "the TV guide is not XMLTV"))]
    NotXmltv,
}

/// Wraps [input] in a gzip decoder when it starts with the gzip magic bytes.
pub fn decompressing<R: Read + 'static>(input: R) -> std::io::Result<Box<dyn BufRead>> {
    let mut buffered = BufReader::with_capacity(256 * 1024, input);
    let head = buffered.fill_buf()?;
    if head.starts_with(&[0x1f, 0x8b]) {
        Ok(Box::new(BufReader::with_capacity(256 * 1024, flate2::bufread::MultiGzDecoder::new(buffered))))
    } else {
        Ok(Box::new(buffered))
    }
}

/// Reads an XMLTV document, calling [on_channel] and [on_programme] in
/// document order. Unknown elements are skipped; a broken programme is
/// counted and skipped rather than failing the whole guide.
pub fn parse(
    input: impl BufRead,
    mut on_channel: impl FnMut(XChannel),
    mut on_programme: impl FnMut(XProgramme),
) -> Result<Stats, XmltvError> {
    let mut reader = Reader::from_reader(input);
    reader.config_mut().trim_text(true);
    let mut buf = Vec::with_capacity(8 * 1024);
    let mut stats = Stats::default();
    let mut seen_root = false;

    let mut ctx = Ctx::None;
    // The text-bearing child we are inside, if any.
    let mut field: Option<&'static str> = None;

    loop {
        let event = reader.read_event_into(&mut buf).map_err(|e| XmltvError::Read(e.to_string()))?;
        match event {
            Event::Start(e) | Event::Empty(e) if !seen_root => {
                if e.name().as_ref() != b"tv" {
                    return Err(XmltvError::NotXmltv);
                }
                seen_root = true;
            }
            Event::Start(e) => match e.name().as_ref() {
                b"channel" => ctx = Ctx::Channel(XChannel { id: attr(&e, b"id").unwrap_or_default(), names: Vec::new(), icon: None }),
                b"programme" => ctx = start_programme(&e),
                b"display-name" => field = Some("name"),
                b"title" => field = Some("title"),
                b"desc" => field = Some("desc"),
                _ => {}
            },
            Event::Empty(e) => {
                if e.name().as_ref() == b"icon" {
                    if let Ctx::Channel(c) = &mut ctx {
                        c.icon = attr(&e, b"src");
                    }
                } else if e.name().as_ref() == b"programme" {
                    // A programme with no children has no title: skip it.
                    stats.skipped += 1;
                }
            }
            Event::Text(t) => {
                let Some(f) = field else { continue };
                let text = t.unescape().map(|c| c.into_owned()).unwrap_or_else(|_| String::from_utf8_lossy(&t).into_owned());
                match (&mut ctx, f) {
                    (Ctx::Channel(c), "name") => c.names.push(text),
                    // First title/desc wins: later ones are other languages.
                    (Ctx::Programme { p, .. }, "title") if p.title.is_empty() => p.title = text,
                    (Ctx::Programme { p, .. }, "desc") if p.description.is_empty() => p.description = text,
                    _ => {}
                }
            }
            Event::CData(t) => {
                if let (Some("desc"), Ctx::Programme { p, .. }) = (field, &mut ctx) {
                    if p.description.is_empty() {
                        p.description = String::from_utf8_lossy(&t).into_owned();
                    }
                }
            }
            Event::End(e) => match e.name().as_ref() {
                b"channel" => {
                    if let Ctx::Channel(c) = std::mem::replace(&mut ctx, Ctx::None) {
                        if !c.id.is_empty() {
                            stats.channels += 1;
                            on_channel(c);
                        }
                    }
                }
                b"programme" => {
                    if let Ctx::Programme { p, ok } = std::mem::replace(&mut ctx, Ctx::None) {
                        if ok && !p.title.is_empty() {
                            stats.programmes += 1;
                            on_programme(p);
                        } else {
                            stats.skipped += 1;
                        }
                    }
                }
                b"display-name" | b"title" | b"desc" => field = None,
                _ => {}
            },
            Event::Eof => break,
            _ => {}
        }
        buf.clear();
    }
    if !seen_root {
        return Err(XmltvError::NotXmltv);
    }
    Ok(stats)
}

/// What the parser is inside of.
enum Ctx {
    None,
    Channel(XChannel),
    Programme { p: XProgramme, ok: bool },
}

fn start_programme(e: &BytesStart<'_>) -> Ctx {
    let start = attr(e, b"start").and_then(|s| parse_time(&s));
    let stop = attr(e, b"stop").and_then(|s| parse_time(&s));
    let channel = attr(e, b"channel").unwrap_or_default();
    // A missing stop is filled from the next programme by the store; keep
    // it as the start for now.
    let ok = start.is_some() && !channel.is_empty();
    let start = start.unwrap_or(0);
    Ctx::Programme {
        p: XProgramme { channel, start, stop: stop.unwrap_or(start), title: String::new(), description: String::new() },
        ok,
    }
}

fn attr(e: &BytesStart<'_>, name: &[u8]) -> Option<String> {
    e.attributes()
        .flatten()
        .find(|a| a.key.as_ref() == name)
        .and_then(|a| a.unescape_value().ok().map(|v| v.trim().to_string()))
        .filter(|v| !v.is_empty())
}

/// XMLTV time: `YYYYMMDDhhmmss` (seconds optional) and an optional
/// `±HHMM` offset; no offset means UTC. Returns Unix seconds.
pub fn parse_time(s: &str) -> Option<i64> {
    let s = s.trim();
    let (digits, rest) = s.split_at(s.find(|c: char| !c.is_ascii_digit()).unwrap_or(s.len()));
    let digits = match digits.len() {
        12 => format!("{digits}00"),
        14 => digits.to_string(),
        _ => return None,
    };
    let naive = NaiveDateTime::parse_from_str(&digits, "%Y%m%d%H%M%S").ok()?;
    let offset = rest.trim();
    let secs = if offset.is_empty() || offset.eq_ignore_ascii_case("utc") || offset.eq_ignore_ascii_case("gmt") {
        0
    } else {
        let (sign, hm) = match offset.as_bytes().first()? {
            b'+' => (1, &offset[1..]),
            b'-' => (-1, &offset[1..]),
            _ => return None,
        };
        let hm = hm.replace(':', "");
        if hm.len() != 4 {
            return None;
        }
        sign * (hm[..2].parse::<i32>().ok()? * 3600 + hm[2..].parse::<i32>().ok()? * 60)
    };
    let tz = FixedOffset::east_opt(secs)?;
    Some(tz.from_local_datetime(&naive).single()?.timestamp())
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE tv SYSTEM "xmltv.dtd">
<tv generator-info-name="test">
  <channel id="trt1.tr">
    <display-name lang="tr">TRT 1</display-name>
    <display-name>TRT 1 HD</display-name>
    <icon src="http://logo/trt1.png"/>
  </channel>
  <programme start="20261021200000 +0300" stop="20261021213000 +0300" channel="trt1.tr">
    <title lang="tr">Ana Haber &amp; Hava</title>
    <title lang="en">News</title>
    <desc lang="tr"><![CDATA[Günün <özeti>.]]></desc>
  </programme>
  <programme start="20261021183000" channel="trt1.tr"><title>Saatsiz bitiş</title></programme>
  <programme start="bozuk" stop="20261021213000 +0300" channel="trt1.tr"><title>Bozuk</title></programme>
  <programme start="20261021220000 +0300" stop="20261021230000 +0300" channel="trt1.tr"/>
</tv>"#;

    #[test]
    fn channels_and_programmes_stream_out() {
        let (mut chans, mut progs) = (Vec::new(), Vec::new());
        let stats = parse(SAMPLE.as_bytes(), |c| chans.push(c), |p| progs.push(p)).unwrap();
        assert_eq!(stats, Stats { channels: 1, programmes: 2, skipped: 2 });
        assert_eq!(chans[0].names, vec!["TRT 1", "TRT 1 HD"]);
        assert_eq!(chans[0].icon.as_deref(), Some("http://logo/trt1.png"));
        // 20:00 +03:00 = 17:00 UTC.
        assert_eq!(progs[0].start, parse_time("20261021170000").unwrap());
        assert_eq!(progs[0].stop - progs[0].start, 5400);
        assert_eq!(progs[0].title, "Ana Haber & Hava", "first title wins, entities decoded");
        assert_eq!(progs[0].description, "Günün <özeti>.");
        assert_eq!(progs[1].stop, progs[1].start, "missing stop left for the store to fill");
    }

    #[test]
    fn gzip_is_detected_by_content() {
        use std::io::Write;
        let mut gz = flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::fast());
        gz.write_all(SAMPLE.as_bytes()).unwrap();
        let bytes = gz.finish().unwrap();
        let mut n = 0;
        parse(decompressing(std::io::Cursor::new(bytes)).unwrap(), |_| {}, |_| n += 1).unwrap();
        assert_eq!(n, 2);
    }

    #[test]
    fn not_a_guide() {
        assert!(matches!(parse("<html><body/></html>".as_bytes(), |_| {}, |_| {}), Err(XmltvError::NotXmltv)));
    }

    #[test]
    fn times_with_and_without_offsets() {
        let utc = parse_time("20260329010000 +0000").unwrap();
        assert_eq!(parse_time("20260329010000").unwrap(), utc);
        assert_eq!(parse_time("202603290100 +0000").unwrap(), utc);
        assert_eq!(parse_time("20260329030000 +0200").unwrap(), utc);
        assert_eq!(parse_time("20260328200000 -05:00").unwrap(), utc);
        assert!(parse_time("2026").is_none());
    }
}
