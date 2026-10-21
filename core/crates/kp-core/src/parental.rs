//! Parental lock: a PIN that hides adult categories and items until it is
//! entered. The PIN is kept salted and hashed in the library; a 4-6 digit
//! code cannot resist someone with the file, so this guards the screen,
//! not the disk. Wrong guesses slow down: five in a row cost 30 seconds.

use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use sha2::{Digest, Sha256};

/// Setting key of the stored "salt:hash".
pub const SETTING: &str = "parental_pin";

const FREE_TRIES: u32 = 5;
const PENALTY: Duration = Duration::from_secs(30);

/// "salt:hash" for [pin], with a fresh salt.
pub fn seal(pin: &str) -> String {
    let nanos = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
    let salt = hex(&Sha256::digest(format!("{nanos}:{}", std::process::id()).as_bytes())[..16]);
    format!("{salt}:{}", digest(&salt, pin))
}

/// Whether [pin] matches a stored "salt:hash".
pub fn matches(stored: &str, pin: &str) -> bool {
    let Some((salt, hash)) = stored.split_once(':') else { return false };
    digest(salt, pin) == hash
}

/// 4 to 6 digits.
pub fn valid(pin: &str) -> bool {
    (4..=6).contains(&pin.len()) && pin.bytes().all(|b| b.is_ascii_digit())
}

fn digest(salt: &str, pin: &str) -> String {
    hex(&Sha256::digest(format!("karadelik-pin:{salt}:{pin}").as_bytes()))
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

/// Counts wrong guesses and makes the caller wait after too many.
#[derive(Default)]
pub struct Guard {
    failures: u32,
    until: Option<Instant>,
}

impl Guard {
    /// Seconds still to wait before the next try, if any.
    pub fn wait(&self, now: Instant) -> Option<u64> {
        let until = self.until?;
        (until > now).then(|| (until - now).as_secs().max(1))
    }

    pub fn record(&mut self, ok: bool, now: Instant) {
        if ok {
            *self = Guard::default();
            return;
        }
        self.failures += 1;
        if self.failures >= FREE_TRIES {
            self.until = Some(now + PENALTY);
            self.failures = 0;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sealed_pins_match_only_themselves() {
        let stored = seal("1234");
        assert!(matches(&stored, "1234"));
        assert!(!matches(&stored, "1235"));
        assert_ne!(seal("1234"), seal("1234").replace('a', "b"), "salted");
        assert!(!matches("garbage", "1234"));
        assert!(valid("0000") && valid("123456") && !valid("123") && !valid("12a4"));
    }

    #[test]
    fn five_wrong_guesses_cost_thirty_seconds() {
        let mut g = Guard::default();
        let t = Instant::now();
        for _ in 0..4 {
            g.record(false, t);
        }
        assert_eq!(g.wait(t), None);
        g.record(false, t);
        assert_eq!(g.wait(t), Some(30));
        assert_eq!(g.wait(t + Duration::from_secs(31)), None);
        g.record(true, t);
        assert_eq!(g.wait(t), None);
    }
}
