//! Region of a category or channel, read from how providers label them:
//! `TR: Ulusal`, `|DE| Sport`, `[UK] News`, `US - Movies`, `Türk Sinema`.
//!
//! Used to put the user's own country first while keeping the provider's
//! order everywhere else.

use crate::text::fold;

/// ISO-style codes providers put in front of names. Only codes that are
/// unambiguous as a leading token are listed ("IN" and "IT" are common
/// words in other contexts, so they need a separator to count).
const CODES: &[&str] = &[
    "TR", "DE", "AT", "CH", "UK", "GB", "US", "USA", "CA", "FR", "ES", "PT", "NL", "BE", "PL", "RO", "BG",
    "GR", "AL", "RS", "HR", "BA", "MK", "SI", "HU", "CZ", "SK", "SE", "NO", "DK", "FI", "RU", "UA", "AZ",
    "AR", "IR", "IL", "EG", "MA", "DZ", "TN", "SA", "AE", "QA", "KW", "PK", "AU", "NZ", "BR", "MX", "LAT",
    "IT", "IN", "EXYU", "KU", "KURD",
];

const WORD_LIKE: &[&str] = &["IT", "IN", "AR", "AL", "BE", "NO", "CA", "MA", "KU"];

/// Whole-word names that identify a region when no code prefix exists.
const NAMES: &[(&str, &str)] = &[
    ("turk", "TR"),
    ("turkiye", "TR"),
    ("turkey", "TR"),
    ("turkish", "TR"),
    ("turkce", "TR"),
    ("deutsch", "DE"),
    ("deutschland", "DE"),
    ("germany", "DE"),
    ("german", "DE"),
    ("france", "FR"),
    ("francais", "FR"),
    ("italia", "IT"),
    ("espana", "ES"),
    ("arabic", "AR"),
    ("azerbaijan", "AZ"),
];

/// Detects a region code, or `None` when the label carries none.
pub fn detect_region(label: &str) -> Option<&'static str> {
    if label.contains('\u{1F1F9}') && label.contains('\u{1F1F7}') {
        return Some("TR"); // 🇹🇷 flag
    }
    let trimmed = label.trim_start_matches(|c: char| c == '|' || c == '[' || c == '(' || c.is_whitespace() || c == '#');
    // Leading code: letters followed by a separator (`TR:`, `TR |`, `TR -`, `TR]`).
    let lead: String = trimmed.chars().take_while(|c| c.is_ascii_alphabetic()).collect();
    if !lead.is_empty() && lead.len() <= 4 {
        let rest = &trimmed[lead.len()..];
        let upper = lead.to_ascii_uppercase();
        let next = rest.chars().next();
        let punct = next.map(|c| matches!(c, ':' | '|' | ']' | ')' | '-' | '/' | '.' | '_' | '•')).unwrap_or(false);
        // Codes that are also English words ("IT Crowd", "IN Focus") only
        // count with punctuation after them; the rest accept a space too.
        let separated = if WORD_LIKE.contains(&upper.as_str()) {
            punct || rest.trim_start().starts_with(['|', ':', '-'])
        } else {
            punct || next.map(char::is_whitespace).unwrap_or(false)
        };
        // Lower-case "tr" alone is too risky ("tv", "in", "it"); require the
        // provider's usual capitals.
        if separated && lead == upper {
            if let Some(code) = CODES.iter().find(|c| **c == upper) {
                return Some(match *code {
                    "GB" => "UK",
                    "USA" => "US",
                    "KURD" => "KU",
                    other => other,
                });
            }
        }
    }
    let folded = fold(label);
    for word in folded.split(|c: char| !c.is_ascii_alphanumeric()).filter(|w| !w.is_empty()) {
        if let Some((_, code)) = NAMES.iter().find(|(n, _)| *n == word) {
            return Some(code);
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::detect_region;

    #[test]
    fn detects_common_provider_labels() {
        for (label, want) in [
            ("TR: Ulusal", Some("TR")),
            ("|TR| SPOR", Some("TR")),
            ("[DE] Sport", Some("DE")),
            ("UK - News", Some("UK")),
            ("USA | Movies", Some("US")),
            ("GB: Kids", Some("UK")),
            ("Türk Sinema", Some("TR")),
            ("TÜRKİYE 4K", Some("TR")),
            ("Ulusal 🇹🇷", Some("TR")),
            ("Deutschland HD", Some("DE")),
        ] {
            assert_eq!(detect_region(label), want, "{label}");
        }
    }

    #[test]
    fn ignores_words_that_only_look_like_codes() {
        for label in ["TRT 1 HD", "Ulusal", "Haber", "tv8", "Inside Sports", "IT Crowd", "Trabzonspor TV", "ATV"] {
            assert_eq!(detect_region(label), None, "{label}");
        }
    }
}
