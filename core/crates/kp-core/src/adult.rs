//! Adult-content detection on channel, group and category labels.

use crate::text::fold;

/// Whole words that mark a label as adult. Matched as whole words on purpose:
/// a bare substring check marks "Sussex" and "Hotbird" as adult.
const WORDS: &[&str] = &[
    "adult", "adults", "yetiskin", "brazzers", "playboy", "hustler", "penthouse", "dorcel",
    "redlight",
];

/// Word prefixes: erotik/erotic/erotica, porn/porno, sex/sexy/sexo.
const PREFIXES: &[&str] = &["erot", "porn", "sex"];

/// True when a label reads as adult content.
pub fn is_adult_label(text: &str) -> bool {
    if text.is_empty() {
        return false;
    }
    let folded = fold(text);
    let words: Vec<&str> = folded
        .split(|c: char| !c.is_ascii_alphanumeric())
        .filter(|w| !w.is_empty())
        .collect();

    let word_hit = words.iter().any(|w| {
        (w.len() >= 3 && w.bytes().all(|b| b == b'x'))
            || WORDS.contains(w)
            || PREFIXES.iter().any(|p| w.starts_with(p))
    });
    word_hit || has_eighteen_marker(&folded, &words)
}

/// "18+", "+18" and "18 yas" as standalone markers.
fn has_eighteen_marker(folded: &str, words: &[&str]) -> bool {
    let compact: String = folded.chars().filter(|c| !c.is_whitespace()).collect();
    let bytes = compact.as_bytes();
    let mut i = 0;
    while let Some(pos) = compact[i..].find("18") {
        let at = i + pos;
        let before_ok = at == 0 || !bytes[at - 1].is_ascii_digit();
        let after = at + 2;
        let after_ok = after >= bytes.len() || !bytes[after].is_ascii_digit();
        if before_ok && after_ok {
            let plus_after = bytes.get(after) == Some(&b'+');
            let plus_before = at > 0 && bytes[at - 1] == b'+';
            if plus_after || plus_before {
                return true;
            }
        }
        i = at + 2;
    }
    words.windows(2).any(|w| w[0] == "18" && w[1] == "yas")
}

#[cfg(test)]
mod tests {
    use super::is_adult_label;

    #[test]
    fn detects_adult_labels() {
        for label in ["XXX", "Yetişkin", "YETISKIN", "18+ Kanallar", "+18", "18 yaş", "Erotik", "Sexy TV", "Brazzers TV"] {
            assert!(is_adult_label(label), "{label}");
        }
    }

    #[test]
    fn ignores_lookalikes() {
        for label in ["Sussex News", "Middlesex", "Hotbird", "Kanal 1", "2018 Dünya Kupası", "Ulusal", "TRT 1 HD"] {
            assert!(!is_adult_label(label), "{label}");
        }
    }
}
