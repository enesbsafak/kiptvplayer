//! Data core of Karadelik IPTV Player.
//!
//! Owns everything that is not pixels or playback: parsing provider catalogs,
//! storing them in SQLite so the UI can paint from disk on launch, and search.

pub mod adult;
pub mod backup;
pub mod catalog;
pub mod catchup;
pub mod core;
pub mod guide;
pub mod lang;
pub mod parental;
pub mod m3u;
pub mod net;
pub mod opensubs;
pub mod region;
pub mod secret;
pub mod stalker;
pub mod store;
pub mod text;
pub mod tmdb;
pub mod update;
pub mod xmltv;
pub mod xtream;

pub use catalog::{Catalog, CategoryRecord, ChannelRecord, ContentKind, XtreamLists};
pub use store::{ChannelRow, Store, StoreError};

/// Sent to providers unless a source overrides it. Generic on purpose: some
/// panels block unknown agents, and this one identifies no brand.
pub const DEFAULT_USER_AGENT: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36";
