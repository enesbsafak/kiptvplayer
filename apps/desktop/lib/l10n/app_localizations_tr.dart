// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get navHome => 'Ana Sayfa';

  @override
  String get navLive => 'Canlı TV';

  @override
  String get navGuide => 'Yayın Akışı';

  @override
  String get navMovies => 'Filmler';

  @override
  String get navSeries => 'Diziler';

  @override
  String get navFavorites => 'Favoriler';

  @override
  String get navLibrary => 'Kütüphane';

  @override
  String get navSearch => 'Ara';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get sourceAddEllipsis => 'Kaynak ekle…';

  @override
  String get sourceNone => 'Kaynak yok';

  @override
  String get sourceAddOne => 'Bir kaynak ekleyin';

  @override
  String get sourceSyncError => 'Eşitleme hatası';

  @override
  String sourceItemCount(String count) {
    return '$count içerik';
  }

  @override
  String get thousandsSeparator => '.';

  @override
  String get tipSearch => 'Ara (Ctrl K)';

  @override
  String get tipSettings => 'Ayarlar (Ctrl ,)';

  @override
  String get tipPlayPause => 'Oynat / duraklat';

  @override
  String get tipExpand => 'Büyüt';

  @override
  String get tipClose => 'Kapat';

  @override
  String durationHours(int h, String m) {
    return '$h sa $m dk';
  }

  @override
  String durationMinutes(int m) {
    return '$m dk';
  }

  @override
  String get dayToday => 'Bugün';

  @override
  String get dayYesterday => 'Dün';

  @override
  String get sourceNoneHint =>
      'Ayarlar › Kaynaklar bölümünden bir kaynak ekleyin.';

  @override
  String get homeContinue => 'Devam et';

  @override
  String get homeRecentChannels => 'Son izlenen kanallar';

  @override
  String get homeFavoriteChannels => 'Favori kanallar';

  @override
  String get homeNewMovies => 'Yeni eklenen filmler';

  @override
  String get homeNewSeries => 'Yeni eklenen diziler';

  @override
  String get syncConnecting => 'Bağlanılıyor…';

  @override
  String syncDownloading(String what) {
    return '$what indiriliyor…';
  }

  @override
  String get syncSaving => 'Kaydediliyor…';

  @override
  String homeLastSync(String ago) {
    return 'Son eşitleme $ago';
  }

  @override
  String homeAccountUntil(String date) {
    return 'Hesap $date tarihine kadar';
  }

  @override
  String homeConnections(int n) {
    return '$n bağlantı';
  }

  @override
  String get actionSync => 'Eşitle';

  @override
  String get greetNight => 'İyi geceler';

  @override
  String get greetMorning => 'Günaydın';

  @override
  String get greetDay => 'İyi günler';

  @override
  String get greetEvening => 'İyi akşamlar';

  @override
  String get agoNow => 'az önce';

  @override
  String get actionAll => 'Tümü';

  @override
  String get liveShort => 'Canlı';

  @override
  String get tipLiveHint =>
      '↑ ↓ ile kanal değiştirin, Enter ile tam ekrana geçin.';

  @override
  String get tipFavoritesHint =>
      'Sık izlediğiniz kanalları yıldızlayın; ana sayfada görünür.';

  @override
  String get tipSearchTitle => 'Hızlı arama';

  @override
  String get tipSearchHint => 'Ctrl K ile kanal, film ve dizilerde arayın.';

  @override
  String get goToLive => 'Canlı TV\'ye git';

  @override
  String agoMinutes(int n) {
    return '$n dk önce';
  }

  @override
  String agoHours(int n) {
    return '$n sa önce';
  }

  @override
  String agoDays(int n) {
    return '$n gün önce';
  }

  @override
  String get searchHint => 'Kanal, film veya dizi ara';

  @override
  String get searchEmptyTitle => 'Ne izlemek istersiniz?';

  @override
  String get searchEmptyHint =>
      'Yazmaya başlayın; Türkçe karakterler olmadan da bulur.';

  @override
  String searchNoResults(String q) {
    return '“$q” için sonuç yok';
  }

  @override
  String get kindChannels => 'Kanallar';

  @override
  String get favEmptyTitle => 'Henüz favori yok';

  @override
  String get favEmptyHint =>
      'Kanalları ve içerikleri favoriye ekleyerek burada toplayın.';

  @override
  String get actionRemove => 'Kaldır';

  @override
  String get liveCategories => 'Kategoriler';

  @override
  String get liveAllChannels => 'Tüm kanallar';

  @override
  String get liveFilterHint => 'Bu listede ara';

  @override
  String get liveNoFavorites => 'Favori kanal yok';

  @override
  String get liveNoChannels => 'Kanal bulunamadı';

  @override
  String get liveNoFavoritesHint => 'Bir kanalı yıldızlayarak buraya ekleyin.';

  @override
  String get liveHasArchive => 'Geçmiş yayın var';

  @override
  String get livePickChannel => 'Önizlemek için bir kanal seçin';

  @override
  String get livePickChannelHint =>
      '↑ ↓ ile kanal değiştirin, Enter ile tam ekran';

  @override
  String get tagLive => 'CANLI';

  @override
  String get favOn => 'Favoride';

  @override
  String get favOff => 'Favori';

  @override
  String get actionFullscreen => 'Tam ekran';

  @override
  String get liveNoGuide => 'Yayın akışı bilgisi yok.';

  @override
  String get guideNow => 'Şimdi';

  @override
  String get guideNext => 'Sonra';

  @override
  String get livePastBroadcasts => 'Geçmiş yayınlar';

  @override
  String liveProgrammeCount(int n) {
    return '$n program';
  }

  @override
  String get liveNoArchive => 'Bu kanal için geçmiş yayın listesi yok.';

  @override
  String get liveOlderBroadcasts => 'Daha eski yayınlar';

  @override
  String liveMinutesLeft(int n) {
    return '$n dk kaldı';
  }

  @override
  String get guideEarlier => 'Önceki';

  @override
  String get guideLater => 'Sonraki';

  @override
  String get guideChannel => 'Kanal';

  @override
  String get guideNoData => 'Yayın akışı yok';

  @override
  String get categoryAll => 'Tümü';

  @override
  String get vodEmptyCategory => 'Bu kategoride içerik yok';

  @override
  String get actionBack => 'Geri';

  @override
  String detailFailed(String error) {
    return 'Ayrıntılar alınamadı: $error';
  }

  @override
  String get detailCreator => 'Yaratıcı';

  @override
  String get detailDirector => 'Yönetmen';

  @override
  String get detailCast => 'Oyuncular';

  @override
  String get detailSourceTmdb => 'Bilgiler: TMDB';

  @override
  String detailSeasons(int n) {
    return '$n sezon';
  }

  @override
  String get actionResume => 'Devam et';

  @override
  String get actionPlay => 'Oynat';

  @override
  String get actionFromStart => 'Baştan başlat';

  @override
  String get actionPlayFirstEpisode => 'İlk bölümü oynat';

  @override
  String get actionTrailer => 'Fragman';

  @override
  String get listIn => 'Listemde';

  @override
  String get listAdd => 'Listeme ekle';

  @override
  String get detailEpisodes => 'Bölümler';

  @override
  String detailSeasonN(int n) {
    return '$n. Sezon';
  }

  @override
  String detailVotes(String n) {
    return '$n oy';
  }

  @override
  String get tipBackEsc => 'Geri (Esc)';

  @override
  String get tagCatchup => 'GEÇMİŞ YAYIN';

  @override
  String get tagBackup => 'YEDEK YAYIN';

  @override
  String get actionBackToLive => 'Canlıya dön';

  @override
  String get tipPrevChannel => 'Önceki kanal (↑)';

  @override
  String get tipBack10 => '10 sn geri (←)';

  @override
  String get tipPlayPauseSpace => 'Oynat / duraklat (Space)';

  @override
  String get tipNextChannel => 'Sonraki kanal (↓)';

  @override
  String get tipForward10 => '10 sn ileri (→)';

  @override
  String get tipTracks => 'Ses ve altyazı (A)';

  @override
  String get tipChannelList => 'Kanal listesi (L)';

  @override
  String get tipFullscreen => 'Tam ekran (F)';

  @override
  String get liveBroadcast => 'Canlı yayın';

  @override
  String get tipVolume => 'Ses (M)';

  @override
  String get tracksNone => 'Seçenek yok';

  @override
  String get tracksAudio => 'Ses';

  @override
  String get tracksSubtitles => 'Altyazı';

  @override
  String get tracksOff => 'Kapalı';

  @override
  String get playerOpenFailed => 'Yayın açılamadı';

  @override
  String get actionRetry => 'Tekrar dene';

  @override
  String reconnectIn(int n) {
    return '$n sn içinde yeniden denenecek';
  }

  @override
  String reconnectTitle(String reason) {
    return '$reason · yeniden bağlanılıyor';
  }

  @override
  String get reasonDropped => 'Bağlantı koptu';

  @override
  String reconnectAttempt(int n, String status) {
    return '$n. deneme · $status';
  }

  @override
  String reconnectBackup(String name) {
    return 'Yedek yayın deneniyor: $name';
  }

  @override
  String get actionStop => 'Durdur';

  @override
  String get actionRetryNow => 'Şimdi dene';

  @override
  String get addNeedServer => 'Sunucu adresini girin';

  @override
  String get addNeedListUrl => 'Liste adresini girin';

  @override
  String get addNeedFile => 'Bir M3U dosyası seçin';

  @override
  String get addNeedUser => 'Kullanıcı adını girin';

  @override
  String get addNeedPassword => 'Şifreyi girin';

  @override
  String get syncConnectingProvider => 'Sağlayıcıya bağlanılıyor…';

  @override
  String get syncPreparing => 'Kütüphane hazırlanıyor…';

  @override
  String get addPlaylistFiles => 'Oynatma listesi';

  @override
  String get addXtreamHint => 'Sunucu, kullanıcı adı ve şifre';

  @override
  String get addM3uUrl => 'M3U bağlantısı';

  @override
  String get addM3uUrlHint => 'Oynatma listesi adresi';

  @override
  String get addM3uFile => 'M3U dosyası';

  @override
  String get addM3uFileHint => 'Bilgisayardaki liste';

  @override
  String get addName => 'Ad';

  @override
  String get addNameHint => 'İsteğe bağlı, ör. Ev';

  @override
  String get addUser => 'Kullanıcı adı';

  @override
  String get addPassword => 'Şifre';

  @override
  String get addFile => 'Dosya';

  @override
  String get addNoFile => 'Dosya seçilmedi';

  @override
  String get addChoose => 'Seç…';

  @override
  String get addAdvancedHide => 'Gelişmiş ayarları gizle';

  @override
  String get addAdvanced => 'Gelişmiş ayarlar';

  @override
  String get addUserAgentHint => 'Sağlayıcı isterse';

  @override
  String get addGuideUrl => 'Yayın akışı (XMLTV)';

  @override
  String get addGuideUrlHint => 'Liste bildirmiyorsa: https://…/epg.xml.gz';

  @override
  String get addInsecure => 'Geçersiz sertifikalara izin ver';

  @override
  String get addInsecureHint =>
      'Yalnızca bu kaynak için. Sağlayıcının sertifikası kendinden imzalıysa gerekir.';

  @override
  String get addPasswordNote =>
      'Şifreniz bu bilgisayarın anahtar deposunda saklanır.';

  @override
  String get actionCancel => 'Vazgeç';

  @override
  String get addConnect => 'Bağlan ve eşitle';

  @override
  String addReady(String name) {
    return '$name hazır';
  }

  @override
  String get statLive => 'canlı kanal';

  @override
  String get statMovies => 'film';

  @override
  String get statSeries => 'dizi';

  @override
  String addAccountExpires(String date) {
    return 'Hesap bitiş tarihi: $date';
  }

  @override
  String get actionStart => 'Başla';

  @override
  String get onboardHint => 'Başlamak için bir kaynak ekleyin.';

  @override
  String get onboardDisclaimer =>
      'Karadelik IPTV Player bir oynatıcıdır; kanal, film veya yayın sağlamaz ve satmaz. Yalnızca erişim hakkınız olan kaynakları ekleyin.';

  @override
  String get setSources => 'Kaynaklar';

  @override
  String get setPreferences => 'Tercihler';

  @override
  String get setShortcuts => 'Kısayollar';

  @override
  String get setAbout => 'Hakkında';

  @override
  String get sourceAdd => 'Kaynak ekle';

  @override
  String get sourceNoneYet => 'Henüz kaynak yok.';

  @override
  String get guideDownloading => 'Yayın akışı indiriliyor…';

  @override
  String sourceDeleteTitle(String name) {
    return '$name silinsin mi?';
  }

  @override
  String get sourceDeleteBody =>
      'Kaynağın kataloğu, favorileri ve izleme geçmişi bu bilgisayardan silinir. Şifre anahtar deposundan kaldırılır.';

  @override
  String get actionDelete => 'Sil';

  @override
  String get sourceActive => 'etkin';

  @override
  String sourceCounts(int live, int movies, int series) {
    return '$live kanal · $movies film · $series dizi';
  }

  @override
  String get guideButton => 'Yayın akışı';

  @override
  String get sourceActivate => 'Etkinleştir';

  @override
  String get guideNoUrl =>
      'Yayın akışı yok: liste bir XMLTV adresi bildirmiyor.';

  @override
  String get guideNotYet => 'Yayın akışı henüz indirilmedi.';

  @override
  String guideFailed(String error) {
    return 'Yayın akışı alınamadı: $error';
  }

  @override
  String guideStatus(String matched, String programmes, String ago) {
    return 'Yayın akışı: $matched kanal eşleşti · $programmes program · $ago';
  }

  @override
  String get prefLanguage => 'Uygulama dili';

  @override
  String get prefLanguageSystem => 'Sistem';

  @override
  String get prefRegion => 'Öne çıkan bölge';

  @override
  String get prefRegionBody =>
      'Bu bölgenin kategorileri ve kanalları her listede en başta gösterilir. Diğerleri sağlayıcının sırasıyla devam eder; yetişkin içerik her zaman en sondadır. Bölge, kategori adlarından okunur (ör. “TR: Ulusal”, “|DE| Sport”).';

  @override
  String get prefOff => 'Kapalı';

  @override
  String get prefRegionNone =>
      'Etkin kaynakta bölge etiketi bulunamadı; sıralama sağlayıcının kendi sırası olarak kalır.';

  @override
  String get tmdbRemoved => 'Anahtar kaldırıldı.';

  @override
  String get tmdbSaved => 'Anahtar doğrulandı ve kaydedildi.';

  @override
  String get tmdbTitle => 'TMDB içerik bilgileri';

  @override
  String get tagOn => 'AÇIK';

  @override
  String get tagOff => 'KAPALI';

  @override
  String get tmdbBody =>
      'Film ve dizilerde özet, tür, oyuncu fotoğrafları, fragman, yaş sınırı ve bölüm bilgileri TMDB’den gelir. Anahtar yalnızca bu bilgisayarın anahtar deposunda saklanır; TMDB’ye yalnızca içerik adı ve yılı gönderilir.';

  @override
  String get tmdbReplaceHint => 'Yeni anahtar ile değiştir';

  @override
  String get tmdbKeyHint => 'API anahtarı (v3) veya okuma erişim jetonu (v4)';

  @override
  String get tmdbVerify => 'Doğrula ve kaydet';

  @override
  String get tmdbWhere => 'Anahtarı nereden alırım?';

  @override
  String get tmdbWhereLink => 'themoviedb.org › Ayarlar › API';

  @override
  String get tmdbLanguage => 'Bilgi dili';

  @override
  String get keySections =>
      'Ana sayfa, Canlı TV, Yayın akışı, Filmler, Diziler, Favoriler';

  @override
  String get keyZap => 'Kanal değiştir';

  @override
  String get keyDigits => 'Kanal numarasıyla geç (Enter beklemeden açar)';

  @override
  String get keyMediaKeys => 'Medya tuşları';

  @override
  String get keyMediaKeysDo =>
      'Oynat / duraklat, sonraki / önceki kanal (film ve dizide ileri / geri sarma)';

  @override
  String get keyPage => 'Listede 10 kanal atla';

  @override
  String get keyEnter => 'Tam ekran oynat';

  @override
  String get keySeek => '10 saniye geri / ileri (film ve dizi)';

  @override
  String get keyFKey => 'F, çift tık';

  @override
  String get keyFullscreen => 'Pencereyi tam ekran yap';

  @override
  String get keyTracks => 'Ses ve altyazı paneli';

  @override
  String get keyChannelList => 'Oynatıcıda kanal listesi';

  @override
  String get keyMute => 'Sesi kapat / aç';

  @override
  String get keyEsc => 'Paneli kapat, oynatıcıdan çık';

  @override
  String aboutVersion(String version) {
    return 'Sürüm $version';
  }

  @override
  String get aboutDisclaimer =>
      'Karadelik IPTV Player bir oynatıcıdır. Kanal, film veya yayın sağlamaz, satmaz ve barındırmaz. Eklediğiniz kaynakların yasal olduğundan ve erişim hakkınız bulunduğundan siz sorumlusunuz.';

  @override
  String get aboutPrivacy =>
      'Gizlilik: kaynak şifreleri yalnızca bu bilgisayarın anahtar deposunda tutulur. Uygulama izleme veya reklam SDK’sı içermez.';

  @override
  String get aboutTmdb =>
      'Film ve dizi bilgileri, isteğe bağlı olarak, The Movie Database’den (TMDB) alınır.';

  @override
  String get aboutLicenses => 'Açık kaynak lisansları';

  @override
  String get errNoPicture => 'Yayından görüntü gelmedi';

  @override
  String get reasonStalled => 'Yayın takıldı';

  @override
  String get reasonError => 'Bağlantı hatası';

  @override
  String get reasonEnded => 'Yayın kesildi';

  @override
  String trackN(int n) {
    return 'Parça $n';
  }

  @override
  String get trackForced => 'Zorunlu';

  @override
  String get trackExternal => 'Harici';

  @override
  String trackChannels(int n) {
    return '$n kanal';
  }

  @override
  String get trackText => 'Metin';

  @override
  String get mediaCatchup => 'Geçmiş yayın';

  @override
  String get mediaSeries => 'Dizi';

  @override
  String get mediaMovie => 'Film';

  @override
  String get startupFailed => 'Kütüphane açılamadı';

  @override
  String startupDataDir(String dir) {
    return 'Veri klasörü: $dir';
  }

  @override
  String get addServer => 'Sunucu adresi';

  @override
  String get addServerHint => 'http://sunucu:8080';

  @override
  String get addListUrl => 'Liste adresi';

  @override
  String get addStalker => 'Stalker portalı';

  @override
  String get addNeedPortal => 'Portal adresini girin';

  @override
  String get addNeedMac => 'MAC adresini 00:1A:79:12:34:56 biçiminde girin';

  @override
  String get addStalkerHint => 'Portal adresi ve MAC';

  @override
  String get addPortal => 'Portal adresi';

  @override
  String get addMac => 'MAC adresi';
}
