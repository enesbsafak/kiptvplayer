// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navLive => 'Live TV';

  @override
  String get navGuide => 'TV Guide';

  @override
  String get navMovies => 'Movies';

  @override
  String get navSeries => 'Series';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navLibrary => 'Library';

  @override
  String get navSearch => 'Search';

  @override
  String get navSettings => 'Settings';

  @override
  String get sourceAddEllipsis => 'Add source…';

  @override
  String get sourceNone => 'No source';

  @override
  String get sourceAddOne => 'Add a source';

  @override
  String get sourceSyncError => 'Sync failed';

  @override
  String sourceItemCount(String count) {
    return '$count items';
  }

  @override
  String get thousandsSeparator => ',';

  @override
  String get tipSearch => 'Search (Ctrl K)';

  @override
  String get tipSettings => 'Settings (Ctrl ,)';

  @override
  String get tipPlayPause => 'Play / pause';

  @override
  String get tipExpand => 'Expand';

  @override
  String get tipClose => 'Close';

  @override
  String durationHours(int h, String m) {
    return '$h h $m min';
  }

  @override
  String durationMinutes(int m) {
    return '$m min';
  }

  @override
  String get dayToday => 'Today';

  @override
  String get dayYesterday => 'Yesterday';

  @override
  String get sourceNoneHint => 'Add a source in Settings › Sources.';

  @override
  String get homeContinue => 'Continue watching';

  @override
  String get homeRecentChannels => 'Recently watched channels';

  @override
  String get homeFavoriteChannels => 'Favorite channels';

  @override
  String get homeNewMovies => 'Newly added movies';

  @override
  String get homeNewSeries => 'Newly added series';

  @override
  String get syncConnecting => 'Connecting…';

  @override
  String syncDownloading(String what) {
    return 'Downloading $what…';
  }

  @override
  String get syncSaving => 'Saving…';

  @override
  String homeLastSync(String ago) {
    return 'Last synced $ago';
  }

  @override
  String homeAccountUntil(String date) {
    return 'Account valid until $date';
  }

  @override
  String homeConnections(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n connections',
      one: '1 connection',
    );
    return '$_temp0';
  }

  @override
  String get actionSync => 'Sync';

  @override
  String get greetNight => 'Good night';

  @override
  String get greetMorning => 'Good morning';

  @override
  String get greetDay => 'Good afternoon';

  @override
  String get greetEvening => 'Good evening';

  @override
  String get agoNow => 'just now';

  @override
  String get actionAll => 'See all';

  @override
  String get liveShort => 'Live';

  @override
  String get tipLiveHint =>
      'Change channels with ↑ ↓, press Enter for full screen.';

  @override
  String get tipFavoritesHint =>
      'Star the channels you watch often; they show up on Home.';

  @override
  String get tipSearchTitle => 'Quick search';

  @override
  String get tipSearchHint => 'Search channels, movies and series with Ctrl K.';

  @override
  String get goToLive => 'Go to Live TV';

  @override
  String agoMinutes(int n) {
    return '$n min ago';
  }

  @override
  String agoHours(int n) {
    return '$n h ago';
  }

  @override
  String agoDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get searchHint => 'Search channels, movies or series';

  @override
  String get searchEmptyTitle => 'What would you like to watch?';

  @override
  String get searchEmptyHint => 'Start typing; accents are optional.';

  @override
  String searchNoResults(String q) {
    return 'No results for “$q”';
  }

  @override
  String get kindChannels => 'Channels';

  @override
  String get favEmptyTitle => 'No favorites yet';

  @override
  String get favEmptyHint =>
      'Add channels, movies and series to favorites to collect them here.';

  @override
  String get actionRemove => 'Remove';

  @override
  String get liveCategories => 'Categories';

  @override
  String get liveAllChannels => 'All channels';

  @override
  String get liveFilterHint => 'Filter this list';

  @override
  String get liveNoFavorites => 'No favorite channels';

  @override
  String get liveNoChannels => 'No channels found';

  @override
  String get liveNoFavoritesHint => 'Star a channel to add it here.';

  @override
  String get liveHasArchive => 'Catch-up available';

  @override
  String get livePickChannel => 'Pick a channel to preview';

  @override
  String get livePickChannelHint =>
      'Change channels with ↑ ↓, Enter for full screen';

  @override
  String get tagLive => 'LIVE';

  @override
  String get favOn => 'In favorites';

  @override
  String get favOff => 'Favorite';

  @override
  String get actionFullscreen => 'Full screen';

  @override
  String get liveNoGuide => 'No programme information.';

  @override
  String get guideNow => 'Now';

  @override
  String get guideNext => 'Next';

  @override
  String get livePastBroadcasts => 'Past broadcasts';

  @override
  String liveProgrammeCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n programmes',
      one: '1 programme',
    );
    return '$_temp0';
  }

  @override
  String get liveNoArchive => 'No past broadcasts listed for this channel.';

  @override
  String get liveOlderBroadcasts => 'Older broadcasts';

  @override
  String liveMinutesLeft(int n) {
    return '$n min left';
  }

  @override
  String get guideEarlier => 'Earlier';

  @override
  String get guideLater => 'Later';

  @override
  String get guideChannel => 'Channel';

  @override
  String get guideNoData => 'No guide data';

  @override
  String get categoryAll => 'All';

  @override
  String get vodEmptyCategory => 'Nothing in this category';

  @override
  String get actionBack => 'Back';

  @override
  String detailFailed(String error) {
    return 'Could not load details: $error';
  }

  @override
  String get detailCreator => 'Created by';

  @override
  String get detailDirector => 'Director';

  @override
  String get detailCast => 'Cast';

  @override
  String get detailSourceTmdb => 'Information: TMDB';

  @override
  String detailSeasons(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n seasons',
      one: '1 season',
    );
    return '$_temp0';
  }

  @override
  String get actionResume => 'Resume';

  @override
  String get actionPlay => 'Play';

  @override
  String get actionFromStart => 'Start over';

  @override
  String get actionPlayFirstEpisode => 'Play first episode';

  @override
  String get actionTrailer => 'Trailer';

  @override
  String get listIn => 'In my list';

  @override
  String get listAdd => 'Add to my list';

  @override
  String get detailEpisodes => 'Episodes';

  @override
  String detailSeasonN(int n) {
    return 'Season $n';
  }

  @override
  String detailVotes(String n) {
    return '$n votes';
  }

  @override
  String get tipBackEsc => 'Back (Esc)';

  @override
  String get tagCatchup => 'CATCH-UP';

  @override
  String get tagBackup => 'BACKUP STREAM';

  @override
  String get actionBackToLive => 'Back to live';

  @override
  String get tipPrevChannel => 'Previous channel (↑)';

  @override
  String get tipBack10 => 'Back 10 s (←)';

  @override
  String get tipPlayPauseSpace => 'Play / pause (Space)';

  @override
  String get tipNextChannel => 'Next channel (↓)';

  @override
  String get tipForward10 => 'Forward 10 s (→)';

  @override
  String get tipTracks => 'Audio and subtitles (A)';

  @override
  String get tipChannelList => 'Channel list (L)';

  @override
  String get tipFullscreen => 'Full screen (F)';

  @override
  String get liveBroadcast => 'Live broadcast';

  @override
  String get tipVolume => 'Volume (M)';

  @override
  String get tracksNone => 'None available';

  @override
  String get tracksAudio => 'Audio';

  @override
  String get tracksSubtitles => 'Subtitles';

  @override
  String get tracksOff => 'Off';

  @override
  String get playerOpenFailed => 'Could not open the stream';

  @override
  String get actionRetry => 'Try again';

  @override
  String reconnectIn(int n) {
    return 'Retrying in $n s';
  }

  @override
  String reconnectTitle(String reason) {
    return '$reason · reconnecting';
  }

  @override
  String get reasonDropped => 'Connection lost';

  @override
  String reconnectAttempt(int n, String status) {
    return 'Attempt $n · $status';
  }

  @override
  String reconnectBackup(String name) {
    return 'Trying backup stream: $name';
  }

  @override
  String get actionStop => 'Stop';

  @override
  String get actionRetryNow => 'Retry now';

  @override
  String get addNeedServer => 'Enter the server address';

  @override
  String get addNeedListUrl => 'Enter the playlist address';

  @override
  String get addNeedFile => 'Choose an M3U file';

  @override
  String get addNeedUser => 'Enter the username';

  @override
  String get addNeedPassword => 'Enter the password';

  @override
  String get syncConnectingProvider => 'Connecting to the provider…';

  @override
  String get syncPreparing => 'Preparing the library…';

  @override
  String get addPlaylistFiles => 'Playlist';

  @override
  String get addXtreamHint => 'Server, username and password';

  @override
  String get addM3uUrl => 'M3U link';

  @override
  String get addM3uUrlHint => 'Playlist address';

  @override
  String get addM3uFile => 'M3U file';

  @override
  String get addM3uFileHint => 'A playlist on this computer';

  @override
  String get addName => 'Name';

  @override
  String get addNameHint => 'Optional, e.g. Home';

  @override
  String get addUser => 'Username';

  @override
  String get addPassword => 'Password';

  @override
  String get addFile => 'File';

  @override
  String get addNoFile => 'No file chosen';

  @override
  String get addChoose => 'Choose…';

  @override
  String get addAdvancedHide => 'Hide advanced settings';

  @override
  String get addAdvanced => 'Advanced settings';

  @override
  String get addUserAgentHint => 'If the provider asks for one';

  @override
  String get addGuideUrl => 'TV guide (XMLTV)';

  @override
  String get addGuideUrlHint =>
      'If the playlist names none: https://…/epg.xml.gz';

  @override
  String get addInsecure => 'Allow invalid certificates';

  @override
  String get addInsecureHint =>
      'For this source only. Needed when the provider\'s certificate is self-signed.';

  @override
  String get addPasswordNote =>
      'Your password is kept in this computer\'s credential store.';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get addConnect => 'Connect and sync';

  @override
  String addReady(String name) {
    return '$name is ready';
  }

  @override
  String get statLive => 'live channels';

  @override
  String get statMovies => 'movies';

  @override
  String get statSeries => 'series';

  @override
  String addAccountExpires(String date) {
    return 'Account expires: $date';
  }

  @override
  String get actionStart => 'Get started';

  @override
  String get onboardHint => 'Add a source to get started.';

  @override
  String get onboardDisclaimer =>
      'Karadelik IPTV Player is a player: it does not provide or sell channels, movies or streams. Only add sources you have the right to access.';

  @override
  String get setSources => 'Sources';

  @override
  String get setPreferences => 'Preferences';

  @override
  String get setShortcuts => 'Shortcuts';

  @override
  String get setAbout => 'About';

  @override
  String get sourceAdd => 'Add source';

  @override
  String get sourceNoneYet => 'No sources yet.';

  @override
  String get guideDownloading => 'Downloading the TV guide…';

  @override
  String sourceDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get sourceDeleteBody =>
      'The source\'s catalog, favorites and watch history are removed from this computer. Its password is removed from the credential store.';

  @override
  String get actionDelete => 'Delete';

  @override
  String get sourceActive => 'active';

  @override
  String sourceCounts(int live, int movies, int series) {
    return '$live channels · $movies movies · $series series';
  }

  @override
  String get guideButton => 'TV guide';

  @override
  String get sourceActivate => 'Make active';

  @override
  String get guideNoUrl => 'No TV guide: the playlist names no XMLTV address.';

  @override
  String get guideNotYet => 'The TV guide has not been downloaded yet.';

  @override
  String guideFailed(String error) {
    return 'Could not get the TV guide: $error';
  }

  @override
  String guideStatus(String matched, String programmes, String ago) {
    return 'TV guide: $matched channels matched · $programmes programmes · $ago';
  }

  @override
  String get prefLanguage => 'App language';

  @override
  String get prefLanguageSystem => 'System';

  @override
  String get prefRegion => 'Featured region';

  @override
  String get prefRegionBody =>
      'This region\'s categories and channels come first in every list. The rest keep the provider\'s order; adult content always comes last. The region is read from category names (e.g. “TR: National”, “|DE| Sport”).';

  @override
  String get prefOff => 'Off';

  @override
  String get prefRegionNone =>
      'The active source has no region tags; lists keep the provider\'s own order.';

  @override
  String get tmdbRemoved => 'Key removed.';

  @override
  String get tmdbSaved => 'Key verified and saved.';

  @override
  String get tmdbTitle => 'TMDB details';

  @override
  String get tagOn => 'ON';

  @override
  String get tagOff => 'OFF';

  @override
  String get tmdbBody =>
      'Movies and series get their overview, genres, cast photos, trailer, age rating and episode details from TMDB. The key stays in this computer\'s credential store; only a title and its year are sent to TMDB.';

  @override
  String get tmdbReplaceHint => 'Replace with a new key';

  @override
  String get tmdbKeyHint => 'API key (v3) or read access token (v4)';

  @override
  String get tmdbVerify => 'Verify and save';

  @override
  String get tmdbWhere => 'Where do I get a key?';

  @override
  String get tmdbWhereLink => 'themoviedb.org › Settings › API';

  @override
  String get tmdbLanguage => 'Information language';

  @override
  String get keySections =>
      'Home, Live TV, TV Guide, Movies, Series, Favorites';

  @override
  String get keyZap => 'Change channel';

  @override
  String get keyDigits => 'Go to a channel number (Enter opens it at once)';

  @override
  String get keyMediaKeys => 'Media keys';

  @override
  String get keyMediaKeysDo =>
      'Play / pause, next / previous channel (seek in movies and series)';

  @override
  String get keyPage => 'Skip 10 channels in the list';

  @override
  String get keyEnter => 'Play full screen';

  @override
  String get keySeek => 'Back / forward 10 seconds (movies and series)';

  @override
  String get keyFKey => 'F, double-click';

  @override
  String get keyFullscreen => 'Make the window full screen';

  @override
  String get keyTracks => 'Audio and subtitle panel';

  @override
  String get keyChannelList => 'Channel list in the player';

  @override
  String get keyMute => 'Mute / unmute';

  @override
  String get keyEsc => 'Close the panel, leave the player';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutDisclaimer =>
      'Karadelik IPTV Player is a player. It does not provide, sell or host channels, movies or streams. You are responsible for making sure the sources you add are legal and that you have the right to access them.';

  @override
  String get aboutPrivacy =>
      'Privacy: source passwords stay only in this computer\'s credential store. The app contains no tracking or advertising SDK.';

  @override
  String get aboutTmdb =>
      'Movie and series information optionally comes from The Movie Database (TMDB).';

  @override
  String get aboutLicenses => 'Open-source licenses';

  @override
  String get errNoPicture => 'No picture came from the stream';

  @override
  String get reasonStalled => 'Stream stalled';

  @override
  String get reasonError => 'Connection error';

  @override
  String get reasonEnded => 'Stream ended';

  @override
  String trackN(int n) {
    return 'Track $n';
  }

  @override
  String get trackForced => 'Forced';

  @override
  String get trackExternal => 'External';

  @override
  String trackChannels(int n) {
    return '$n channels';
  }

  @override
  String get trackText => 'Text';

  @override
  String get mediaCatchup => 'Catch-up';

  @override
  String get mediaSeries => 'Series';

  @override
  String get mediaMovie => 'Movie';

  @override
  String get startupFailed => 'Could not open the library';

  @override
  String startupDataDir(String dir) {
    return 'Data folder: $dir';
  }

  @override
  String get addServer => 'Server address';

  @override
  String get addServerHint => 'http://server:8080';

  @override
  String get addListUrl => 'Playlist address';

  @override
  String get addStalker => 'Stalker portal';

  @override
  String get addNeedPortal => 'Enter the portal address';

  @override
  String get addNeedMac => 'Enter the MAC address like 00:1A:79:12:34:56';

  @override
  String get addStalkerHint => 'Portal address and MAC';

  @override
  String get addPortal => 'Portal address';

  @override
  String get addMac => 'MAC address';

  @override
  String get updTitle => 'Updates';

  @override
  String updIdle(String version) {
    return 'Version $version';
  }

  @override
  String get updChecking => 'Checking…';

  @override
  String updUpToDate(String version) {
    return 'You\'re up to date: $version is the latest.';
  }

  @override
  String updAvailable(String version) {
    return 'A new version is available: $version';
  }

  @override
  String updFailed(String error) {
    return 'Could not check: $error';
  }

  @override
  String get updCheck => 'Check for updates';

  @override
  String get updDownload => 'Download';

  @override
  String get updInstall => 'Install and restart';

  @override
  String updRollBack(String version) {
    return 'Go back to $version';
  }

  @override
  String get updBadge => 'Update available';

  @override
  String get updBadgeReady => 'Update ready';

  @override
  String get railFilterHint => 'Filter categories';

  @override
  String get railNoMatch => 'No matching category';

  @override
  String get guidePickCategory => 'Category';

  @override
  String get historyClear => 'Clear';

  @override
  String get historyClearAll => 'Clear watch history';

  @override
  String get historyClearBody =>
      'This source\'s recently watched channels and unfinished movies and episodes are removed. Favorites stay.';

  @override
  String get historyCleared => 'Watch history cleared.';

  @override
  String get historyTitle => 'Watch history';

  @override
  String get adjTitle => 'Adjust';

  @override
  String get adjSubtitleDelay => 'Subtitle delay';

  @override
  String get adjAudioDelay => 'Audio delay';

  @override
  String get adjSubtitleSize => 'Subtitle size';

  @override
  String get adjAspect => 'Aspect ratio';

  @override
  String get adjAspectAuto => 'Auto';

  @override
  String get adjAspectFill => 'Fill';

  @override
  String get adjSpeed => 'Playback speed';

  @override
  String get adjSleep => 'Sleep timer';

  @override
  String get adjSleepOff => 'Off';

  @override
  String adjMinutes(int n) {
    return '$n min';
  }

  @override
  String get adjSleepProgrammeEnd => 'When the show ends';

  @override
  String adjSleepTag(String time) {
    return 'Sleep $time';
  }

  @override
  String get adjAddSubtitle => 'Add subtitle file…';

  @override
  String get adjSubtitleFiles => 'Subtitle files';

  @override
  String adjSubtitleDelayNote(String value) {
    return 'Subtitle delay $value';
  }

  @override
  String get keySubtitleDelay => 'Show subtitles 0.1 s earlier / later';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get tipStats => 'Statistics and diagnosis (I)';

  @override
  String get keyStats => 'Statistics: why does it stutter?';

  @override
  String get actionClose => 'Close';

  @override
  String get statsVideo => 'Video';

  @override
  String get statsDecoder => 'Hardware decoding';

  @override
  String get statsSoftware => 'Off (CPU)';

  @override
  String get statsBitrate => 'Video bitrate';

  @override
  String get statsAudio => 'Audio';

  @override
  String get statsBuffer => 'Buffer';

  @override
  String get statsDownload => 'Download speed';

  @override
  String get statsDropped => 'Dropped frames';

  @override
  String get statsOpen => 'Start time';

  @override
  String get statsReconnects => 'Reconnects';

  @override
  String get statsCheckSource => 'Check the provider';

  @override
  String get statsChecking => 'Checking…';

  @override
  String statsAnswered(int ms) {
    return 'The server answered · $ms ms';
  }

  @override
  String get statsNoAnswer => 'The server did not answer';

  @override
  String statsConnections(int active, int max) {
    return 'Connections $active/$max';
  }

  @override
  String statsExpires(String date) {
    return 'Ends $date';
  }

  @override
  String get findSourceDown =>
      'The provider is not answering: the problem is most likely on their side.';

  @override
  String get findAccountExpired => 'The account appears to have expired.';

  @override
  String get findConnectionLimit =>
      'The connection limit is reached: if the account is open on another device, streams may cut out.';

  @override
  String get findSlowNetwork =>
      'The download speed does not keep up with the stream bitrate: the network or the provider is slow.';

  @override
  String get findCacheLow =>
      'The buffer is almost empty: short stalls are likely.';

  @override
  String get findFramesDropping =>
      'Frames are being dropped: the computer cannot decode the picture fast enough.';

  @override
  String get findSoftwareDecoding =>
      'Hardware decoding is not in use; updating the graphics driver may help.';

  @override
  String get findReconnected =>
      'The stream dropped and reconnected on this channel.';

  @override
  String get findHealthy => 'No problem visible right now.';

  @override
  String get actionWatch => 'Watch';

  @override
  String get actionDismiss => 'Dismiss';

  @override
  String get actionWatchChannelNow => 'Watch the channel now';

  @override
  String get reminderSet => 'Remind me';

  @override
  String get reminderRemove => 'Remove reminder';

  @override
  String reminderStartsAt(String time) {
    return 'Starts at $time';
  }

  @override
  String get reminderStarted => 'On now';
}
