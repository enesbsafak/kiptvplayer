//! The language of messages the core hands to the UI (errors, sync
//! stages). Two languages, chosen by the app; Turkish until told otherwise.

use std::sync::atomic::{AtomicBool, Ordering};

static ENGLISH: AtomicBool = AtomicBool::new(false);

/// "en" switches messages to English; anything else means Turkish.
pub fn set_language(code: &str) {
    ENGLISH.store(code.starts_with("en"), Ordering::Relaxed);
}

pub fn is_english() -> bool {
    ENGLISH.load(Ordering::Relaxed)
}

/// The message in the current language.
pub fn t(tr: &'static str, en: &'static str) -> &'static str {
    if is_english() {
        en
    } else {
        tr
    }
}
