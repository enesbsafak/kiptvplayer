//! Text folding for Turkish-market matching.

use unicode_normalization::UnicodeNormalization;

/// Fold a label to lowercase ASCII-ish text for search and pattern matching.
///
/// Turkish users type "fox turk" for "FOX Türk" and "izle" for "İZLE", and
/// providers spell the same group "Yetişkin", "YETISKIN" or "Yetiskın". So
/// both i forms become plain `i` and every diacritic is stripped. `ı` has no
/// decomposed form, which is why it is mapped by hand before NFD.
pub fn fold(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    for ch in input.chars() {
        match ch {
            'I' | 'İ' | 'ı' => out.push('i'),
            _ => out.extend(ch.to_lowercase()),
        }
    }
    out.nfd().filter(|c| !is_combining_mark(*c)).collect()
}

fn is_combining_mark(c: char) -> bool {
    matches!(c, '\u{0300}'..='\u{036F}')
}

#[cfg(test)]
mod tests {
    use super::fold;

    #[test]
    fn folds_both_i_forms_and_diacritics() {
        assert_eq!(fold("İZLE"), "izle");
        assert_eq!(fold("IZLE"), "izle");
        assert_eq!(fold("Yetiskın"), "yetiskin");
        assert_eq!(fold("FOX Türk Ş"), "fox turk s");
        assert_eq!(fold("Çağrı Öğün"), "cagri ogun");
    }
}
