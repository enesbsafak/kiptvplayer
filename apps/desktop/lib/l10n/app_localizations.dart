import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @navHome.
  ///
  /// In tr, this message translates to:
  /// **'Ana Sayfa'**
  String get navHome;

  /// No description provided for @navLive.
  ///
  /// In tr, this message translates to:
  /// **'Canlı TV'**
  String get navLive;

  /// No description provided for @navGuide.
  ///
  /// In tr, this message translates to:
  /// **'Yayın Akışı'**
  String get navGuide;

  /// No description provided for @navMovies.
  ///
  /// In tr, this message translates to:
  /// **'Filmler'**
  String get navMovies;

  /// No description provided for @navSeries.
  ///
  /// In tr, this message translates to:
  /// **'Diziler'**
  String get navSeries;

  /// No description provided for @navFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favoriler'**
  String get navFavorites;

  /// No description provided for @navLibrary.
  ///
  /// In tr, this message translates to:
  /// **'Kütüphane'**
  String get navLibrary;

  /// No description provided for @navSearch.
  ///
  /// In tr, this message translates to:
  /// **'Ara'**
  String get navSearch;

  /// No description provided for @navSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get navSettings;

  /// No description provided for @sourceAddEllipsis.
  ///
  /// In tr, this message translates to:
  /// **'Kaynak ekle…'**
  String get sourceAddEllipsis;

  /// No description provided for @sourceNone.
  ///
  /// In tr, this message translates to:
  /// **'Kaynak yok'**
  String get sourceNone;

  /// No description provided for @sourceAddOne.
  ///
  /// In tr, this message translates to:
  /// **'Bir kaynak ekleyin'**
  String get sourceAddOne;

  /// No description provided for @sourceSyncError.
  ///
  /// In tr, this message translates to:
  /// **'Eşitleme hatası'**
  String get sourceSyncError;

  /// No description provided for @sourceItemCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} içerik'**
  String sourceItemCount(String count);

  /// No description provided for @thousandsSeparator.
  ///
  /// In tr, this message translates to:
  /// **'.'**
  String get thousandsSeparator;

  /// No description provided for @tipSearch.
  ///
  /// In tr, this message translates to:
  /// **'Ara (Ctrl K)'**
  String get tipSearch;

  /// No description provided for @tipSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar (Ctrl ,)'**
  String get tipSettings;

  /// No description provided for @tipPlayPause.
  ///
  /// In tr, this message translates to:
  /// **'Oynat / duraklat'**
  String get tipPlayPause;

  /// No description provided for @tipExpand.
  ///
  /// In tr, this message translates to:
  /// **'Büyüt'**
  String get tipExpand;

  /// No description provided for @tipClose.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get tipClose;

  /// No description provided for @durationHours.
  ///
  /// In tr, this message translates to:
  /// **'{h} sa {m} dk'**
  String durationHours(int h, String m);

  /// No description provided for @durationMinutes.
  ///
  /// In tr, this message translates to:
  /// **'{m} dk'**
  String durationMinutes(int m);

  /// No description provided for @dayToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get dayToday;

  /// No description provided for @dayYesterday.
  ///
  /// In tr, this message translates to:
  /// **'Dün'**
  String get dayYesterday;

  /// No description provided for @sourceNoneHint.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar › Kaynaklar bölümünden bir kaynak ekleyin.'**
  String get sourceNoneHint;

  /// No description provided for @homeContinue.
  ///
  /// In tr, this message translates to:
  /// **'Devam et'**
  String get homeContinue;

  /// No description provided for @homeRecentChannels.
  ///
  /// In tr, this message translates to:
  /// **'Son izlenen kanallar'**
  String get homeRecentChannels;

  /// No description provided for @homeFavoriteChannels.
  ///
  /// In tr, this message translates to:
  /// **'Favori kanallar'**
  String get homeFavoriteChannels;

  /// No description provided for @homeNewMovies.
  ///
  /// In tr, this message translates to:
  /// **'Yeni eklenen filmler'**
  String get homeNewMovies;

  /// No description provided for @homeNewSeries.
  ///
  /// In tr, this message translates to:
  /// **'Yeni eklenen diziler'**
  String get homeNewSeries;

  /// No description provided for @syncConnecting.
  ///
  /// In tr, this message translates to:
  /// **'Bağlanılıyor…'**
  String get syncConnecting;

  /// No description provided for @syncDownloading.
  ///
  /// In tr, this message translates to:
  /// **'{what} indiriliyor…'**
  String syncDownloading(String what);

  /// No description provided for @syncSaving.
  ///
  /// In tr, this message translates to:
  /// **'Kaydediliyor…'**
  String get syncSaving;

  /// No description provided for @homeLastSync.
  ///
  /// In tr, this message translates to:
  /// **'Son eşitleme {ago}'**
  String homeLastSync(String ago);

  /// No description provided for @homeAccountUntil.
  ///
  /// In tr, this message translates to:
  /// **'Hesap {date} tarihine kadar'**
  String homeAccountUntil(String date);

  /// No description provided for @homeConnections.
  ///
  /// In tr, this message translates to:
  /// **'{n} bağlantı'**
  String homeConnections(int n);

  /// No description provided for @actionSync.
  ///
  /// In tr, this message translates to:
  /// **'Eşitle'**
  String get actionSync;

  /// No description provided for @greetNight.
  ///
  /// In tr, this message translates to:
  /// **'İyi geceler'**
  String get greetNight;

  /// No description provided for @greetMorning.
  ///
  /// In tr, this message translates to:
  /// **'Günaydın'**
  String get greetMorning;

  /// No description provided for @greetDay.
  ///
  /// In tr, this message translates to:
  /// **'İyi günler'**
  String get greetDay;

  /// No description provided for @greetEvening.
  ///
  /// In tr, this message translates to:
  /// **'İyi akşamlar'**
  String get greetEvening;

  /// No description provided for @agoNow.
  ///
  /// In tr, this message translates to:
  /// **'az önce'**
  String get agoNow;

  /// No description provided for @actionAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get actionAll;

  /// No description provided for @liveShort.
  ///
  /// In tr, this message translates to:
  /// **'Canlı'**
  String get liveShort;

  /// No description provided for @tipLiveHint.
  ///
  /// In tr, this message translates to:
  /// **'↑ ↓ ile kanal değiştirin, Enter ile tam ekrana geçin.'**
  String get tipLiveHint;

  /// No description provided for @tipFavoritesHint.
  ///
  /// In tr, this message translates to:
  /// **'Sık izlediğiniz kanalları yıldızlayın; ana sayfada görünür.'**
  String get tipFavoritesHint;

  /// No description provided for @tipSearchTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hızlı arama'**
  String get tipSearchTitle;

  /// No description provided for @tipSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Ctrl K: komutlar, kanallar, filmler ve diziler tek kutuda.'**
  String get tipSearchHint;

  /// No description provided for @goToLive.
  ///
  /// In tr, this message translates to:
  /// **'Canlı TV\'ye git'**
  String get goToLive;

  /// No description provided for @agoMinutes.
  ///
  /// In tr, this message translates to:
  /// **'{n} dk önce'**
  String agoMinutes(int n);

  /// No description provided for @agoHours.
  ///
  /// In tr, this message translates to:
  /// **'{n} sa önce'**
  String agoHours(int n);

  /// No description provided for @agoDays.
  ///
  /// In tr, this message translates to:
  /// **'{n} gün önce'**
  String agoDays(int n);

  /// No description provided for @searchHint.
  ///
  /// In tr, this message translates to:
  /// **'Kanal, film veya dizi ara'**
  String get searchHint;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ne izlemek istersiniz?'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptyHint.
  ///
  /// In tr, this message translates to:
  /// **'Yazmaya başlayın; Türkçe karakterler olmadan da bulur.'**
  String get searchEmptyHint;

  /// No description provided for @searchNoResults.
  ///
  /// In tr, this message translates to:
  /// **'“{q}” için sonuç yok'**
  String searchNoResults(String q);

  /// No description provided for @kindChannels.
  ///
  /// In tr, this message translates to:
  /// **'Kanallar'**
  String get kindChannels;

  /// No description provided for @favEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Henüz favori yok'**
  String get favEmptyTitle;

  /// No description provided for @favEmptyHint.
  ///
  /// In tr, this message translates to:
  /// **'Kanalları ve içerikleri favoriye ekleyerek burada toplayın.'**
  String get favEmptyHint;

  /// No description provided for @actionRemove.
  ///
  /// In tr, this message translates to:
  /// **'Kaldır'**
  String get actionRemove;

  /// No description provided for @liveCategories.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriler'**
  String get liveCategories;

  /// No description provided for @liveAllChannels.
  ///
  /// In tr, this message translates to:
  /// **'Tüm kanallar'**
  String get liveAllChannels;

  /// No description provided for @liveFilterHint.
  ///
  /// In tr, this message translates to:
  /// **'Bu listede ara'**
  String get liveFilterHint;

  /// No description provided for @liveNoFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favori kanal yok'**
  String get liveNoFavorites;

  /// No description provided for @liveNoChannels.
  ///
  /// In tr, this message translates to:
  /// **'Kanal bulunamadı'**
  String get liveNoChannels;

  /// No description provided for @liveNoFavoritesHint.
  ///
  /// In tr, this message translates to:
  /// **'Bir kanalı yıldızlayarak buraya ekleyin.'**
  String get liveNoFavoritesHint;

  /// No description provided for @liveHasArchive.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş yayın var'**
  String get liveHasArchive;

  /// No description provided for @livePickChannel.
  ///
  /// In tr, this message translates to:
  /// **'Önizlemek için bir kanal seçin'**
  String get livePickChannel;

  /// No description provided for @livePickChannelHint.
  ///
  /// In tr, this message translates to:
  /// **'↑ ↓ ile kanal değiştirin, Enter ile tam ekran'**
  String get livePickChannelHint;

  /// No description provided for @tagLive.
  ///
  /// In tr, this message translates to:
  /// **'CANLI'**
  String get tagLive;

  /// No description provided for @favOn.
  ///
  /// In tr, this message translates to:
  /// **'Favoride'**
  String get favOn;

  /// No description provided for @favOff.
  ///
  /// In tr, this message translates to:
  /// **'Favori'**
  String get favOff;

  /// No description provided for @actionFullscreen.
  ///
  /// In tr, this message translates to:
  /// **'Tam ekran'**
  String get actionFullscreen;

  /// No description provided for @liveNoGuide.
  ///
  /// In tr, this message translates to:
  /// **'Yayın akışı bilgisi yok.'**
  String get liveNoGuide;

  /// No description provided for @guideNow.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi'**
  String get guideNow;

  /// No description provided for @guideNext.
  ///
  /// In tr, this message translates to:
  /// **'Sonra'**
  String get guideNext;

  /// No description provided for @livePastBroadcasts.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş yayınlar'**
  String get livePastBroadcasts;

  /// No description provided for @liveProgrammeCount.
  ///
  /// In tr, this message translates to:
  /// **'{n} program'**
  String liveProgrammeCount(int n);

  /// No description provided for @liveNoArchive.
  ///
  /// In tr, this message translates to:
  /// **'Bu kanal için geçmiş yayın listesi yok.'**
  String get liveNoArchive;

  /// No description provided for @liveOlderBroadcasts.
  ///
  /// In tr, this message translates to:
  /// **'Daha eski yayınlar'**
  String get liveOlderBroadcasts;

  /// No description provided for @liveMinutesLeft.
  ///
  /// In tr, this message translates to:
  /// **'{n} dk kaldı'**
  String liveMinutesLeft(int n);

  /// No description provided for @guideEarlier.
  ///
  /// In tr, this message translates to:
  /// **'Önceki'**
  String get guideEarlier;

  /// No description provided for @guideLater.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki'**
  String get guideLater;

  /// No description provided for @guideChannel.
  ///
  /// In tr, this message translates to:
  /// **'Kanal'**
  String get guideChannel;

  /// No description provided for @guideNoData.
  ///
  /// In tr, this message translates to:
  /// **'Yayın akışı yok'**
  String get guideNoData;

  /// No description provided for @categoryAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get categoryAll;

  /// No description provided for @vodEmptyCategory.
  ///
  /// In tr, this message translates to:
  /// **'Bu kategoride içerik yok'**
  String get vodEmptyCategory;

  /// No description provided for @actionBack.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get actionBack;

  /// No description provided for @detailFailed.
  ///
  /// In tr, this message translates to:
  /// **'Ayrıntılar alınamadı: {error}'**
  String detailFailed(String error);

  /// No description provided for @detailCreator.
  ///
  /// In tr, this message translates to:
  /// **'Yaratıcı'**
  String get detailCreator;

  /// No description provided for @detailDirector.
  ///
  /// In tr, this message translates to:
  /// **'Yönetmen'**
  String get detailDirector;

  /// No description provided for @detailCast.
  ///
  /// In tr, this message translates to:
  /// **'Oyuncular'**
  String get detailCast;

  /// No description provided for @detailSourceTmdb.
  ///
  /// In tr, this message translates to:
  /// **'Bilgiler: TMDB'**
  String get detailSourceTmdb;

  /// No description provided for @detailSeasons.
  ///
  /// In tr, this message translates to:
  /// **'{n} sezon'**
  String detailSeasons(int n);

  /// No description provided for @actionResume.
  ///
  /// In tr, this message translates to:
  /// **'Devam et'**
  String get actionResume;

  /// No description provided for @actionPlay.
  ///
  /// In tr, this message translates to:
  /// **'Oynat'**
  String get actionPlay;

  /// No description provided for @actionFromStart.
  ///
  /// In tr, this message translates to:
  /// **'Baştan başlat'**
  String get actionFromStart;

  /// No description provided for @actionPlayFirstEpisode.
  ///
  /// In tr, this message translates to:
  /// **'İlk bölümü oynat'**
  String get actionPlayFirstEpisode;

  /// No description provided for @actionTrailer.
  ///
  /// In tr, this message translates to:
  /// **'Fragman'**
  String get actionTrailer;

  /// No description provided for @listIn.
  ///
  /// In tr, this message translates to:
  /// **'Listemde'**
  String get listIn;

  /// No description provided for @listAdd.
  ///
  /// In tr, this message translates to:
  /// **'Listeme ekle'**
  String get listAdd;

  /// No description provided for @detailEpisodes.
  ///
  /// In tr, this message translates to:
  /// **'Bölümler'**
  String get detailEpisodes;

  /// No description provided for @detailSeasonN.
  ///
  /// In tr, this message translates to:
  /// **'{n}. Sezon'**
  String detailSeasonN(int n);

  /// No description provided for @detailVotes.
  ///
  /// In tr, this message translates to:
  /// **'{n} oy'**
  String detailVotes(String n);

  /// No description provided for @tipBackEsc.
  ///
  /// In tr, this message translates to:
  /// **'Geri (Esc)'**
  String get tipBackEsc;

  /// No description provided for @tagCatchup.
  ///
  /// In tr, this message translates to:
  /// **'GEÇMİŞ YAYIN'**
  String get tagCatchup;

  /// No description provided for @tagBackup.
  ///
  /// In tr, this message translates to:
  /// **'YEDEK YAYIN'**
  String get tagBackup;

  /// No description provided for @actionBackToLive.
  ///
  /// In tr, this message translates to:
  /// **'Canlıya dön'**
  String get actionBackToLive;

  /// No description provided for @tipPrevChannel.
  ///
  /// In tr, this message translates to:
  /// **'Önceki kanal (↑)'**
  String get tipPrevChannel;

  /// No description provided for @tipBack10.
  ///
  /// In tr, this message translates to:
  /// **'10 sn geri (←)'**
  String get tipBack10;

  /// No description provided for @tipPlayPauseSpace.
  ///
  /// In tr, this message translates to:
  /// **'Oynat / duraklat (Space)'**
  String get tipPlayPauseSpace;

  /// No description provided for @tipNextChannel.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki kanal (↓)'**
  String get tipNextChannel;

  /// No description provided for @tipForward10.
  ///
  /// In tr, this message translates to:
  /// **'10 sn ileri (→)'**
  String get tipForward10;

  /// No description provided for @tipTracks.
  ///
  /// In tr, this message translates to:
  /// **'Ses ve altyazı (A)'**
  String get tipTracks;

  /// No description provided for @tipChannelList.
  ///
  /// In tr, this message translates to:
  /// **'Kanal listesi (L)'**
  String get tipChannelList;

  /// No description provided for @tipFullscreen.
  ///
  /// In tr, this message translates to:
  /// **'Tam ekran (F)'**
  String get tipFullscreen;

  /// No description provided for @liveBroadcast.
  ///
  /// In tr, this message translates to:
  /// **'Canlı yayın'**
  String get liveBroadcast;

  /// No description provided for @tipVolume.
  ///
  /// In tr, this message translates to:
  /// **'Ses (M)'**
  String get tipVolume;

  /// No description provided for @tracksNone.
  ///
  /// In tr, this message translates to:
  /// **'Seçenek yok'**
  String get tracksNone;

  /// No description provided for @tracksAudio.
  ///
  /// In tr, this message translates to:
  /// **'Ses'**
  String get tracksAudio;

  /// No description provided for @tracksSubtitles.
  ///
  /// In tr, this message translates to:
  /// **'Altyazı'**
  String get tracksSubtitles;

  /// No description provided for @tracksOff.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı'**
  String get tracksOff;

  /// No description provided for @playerOpenFailed.
  ///
  /// In tr, this message translates to:
  /// **'Yayın açılamadı'**
  String get playerOpenFailed;

  /// No description provided for @actionRetry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get actionRetry;

  /// No description provided for @reconnectIn.
  ///
  /// In tr, this message translates to:
  /// **'{n} sn içinde yeniden denenecek'**
  String reconnectIn(int n);

  /// No description provided for @reconnectTitle.
  ///
  /// In tr, this message translates to:
  /// **'{reason} · yeniden bağlanılıyor'**
  String reconnectTitle(String reason);

  /// No description provided for @reasonDropped.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı koptu'**
  String get reasonDropped;

  /// No description provided for @reconnectAttempt.
  ///
  /// In tr, this message translates to:
  /// **'{n}. deneme · {status}'**
  String reconnectAttempt(int n, String status);

  /// No description provided for @reconnectBackup.
  ///
  /// In tr, this message translates to:
  /// **'Yedek yayın deneniyor: {name}'**
  String reconnectBackup(String name);

  /// No description provided for @actionStop.
  ///
  /// In tr, this message translates to:
  /// **'Durdur'**
  String get actionStop;

  /// No description provided for @actionRetryNow.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi dene'**
  String get actionRetryNow;

  /// No description provided for @addNeedServer.
  ///
  /// In tr, this message translates to:
  /// **'Sunucu adresini girin'**
  String get addNeedServer;

  /// No description provided for @addNeedListUrl.
  ///
  /// In tr, this message translates to:
  /// **'Liste adresini girin'**
  String get addNeedListUrl;

  /// No description provided for @addNeedFile.
  ///
  /// In tr, this message translates to:
  /// **'Bir M3U dosyası seçin'**
  String get addNeedFile;

  /// No description provided for @addNeedUser.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı adını girin'**
  String get addNeedUser;

  /// No description provided for @addNeedPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi girin'**
  String get addNeedPassword;

  /// No description provided for @syncConnectingProvider.
  ///
  /// In tr, this message translates to:
  /// **'Sağlayıcıya bağlanılıyor…'**
  String get syncConnectingProvider;

  /// No description provided for @syncPreparing.
  ///
  /// In tr, this message translates to:
  /// **'Kütüphane hazırlanıyor…'**
  String get syncPreparing;

  /// No description provided for @addPlaylistFiles.
  ///
  /// In tr, this message translates to:
  /// **'Oynatma listesi'**
  String get addPlaylistFiles;

  /// No description provided for @addXtreamHint.
  ///
  /// In tr, this message translates to:
  /// **'Sunucu, kullanıcı adı ve şifre'**
  String get addXtreamHint;

  /// No description provided for @addM3uUrl.
  ///
  /// In tr, this message translates to:
  /// **'M3U bağlantısı'**
  String get addM3uUrl;

  /// No description provided for @addM3uUrlHint.
  ///
  /// In tr, this message translates to:
  /// **'Oynatma listesi adresi'**
  String get addM3uUrlHint;

  /// No description provided for @addM3uFile.
  ///
  /// In tr, this message translates to:
  /// **'M3U dosyası'**
  String get addM3uFile;

  /// No description provided for @addM3uFileHint.
  ///
  /// In tr, this message translates to:
  /// **'Bilgisayardaki liste'**
  String get addM3uFileHint;

  /// No description provided for @addName.
  ///
  /// In tr, this message translates to:
  /// **'Ad'**
  String get addName;

  /// No description provided for @addNameHint.
  ///
  /// In tr, this message translates to:
  /// **'İsteğe bağlı, ör. Ev'**
  String get addNameHint;

  /// No description provided for @addUser.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı adı'**
  String get addUser;

  /// No description provided for @addPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifre'**
  String get addPassword;

  /// No description provided for @addFile.
  ///
  /// In tr, this message translates to:
  /// **'Dosya'**
  String get addFile;

  /// No description provided for @addNoFile.
  ///
  /// In tr, this message translates to:
  /// **'Dosya seçilmedi'**
  String get addNoFile;

  /// No description provided for @addChoose.
  ///
  /// In tr, this message translates to:
  /// **'Seç…'**
  String get addChoose;

  /// No description provided for @addAdvancedHide.
  ///
  /// In tr, this message translates to:
  /// **'Gelişmiş ayarları gizle'**
  String get addAdvancedHide;

  /// No description provided for @addAdvanced.
  ///
  /// In tr, this message translates to:
  /// **'Gelişmiş ayarlar'**
  String get addAdvanced;

  /// No description provided for @addUserAgentHint.
  ///
  /// In tr, this message translates to:
  /// **'Sağlayıcı isterse'**
  String get addUserAgentHint;

  /// No description provided for @addGuideUrl.
  ///
  /// In tr, this message translates to:
  /// **'Yayın akışı (XMLTV)'**
  String get addGuideUrl;

  /// No description provided for @addGuideUrlHint.
  ///
  /// In tr, this message translates to:
  /// **'Liste bildirmiyorsa: https://…/epg.xml.gz'**
  String get addGuideUrlHint;

  /// No description provided for @addInsecure.
  ///
  /// In tr, this message translates to:
  /// **'Geçersiz sertifikalara izin ver'**
  String get addInsecure;

  /// No description provided for @addInsecureHint.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca bu kaynak için. Sağlayıcının sertifikası kendinden imzalıysa gerekir.'**
  String get addInsecureHint;

  /// No description provided for @addPasswordNote.
  ///
  /// In tr, this message translates to:
  /// **'Şifreniz bu bilgisayarın anahtar deposunda saklanır.'**
  String get addPasswordNote;

  /// No description provided for @actionCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get actionCancel;

  /// No description provided for @addConnect.
  ///
  /// In tr, this message translates to:
  /// **'Bağlan ve eşitle'**
  String get addConnect;

  /// No description provided for @addReady.
  ///
  /// In tr, this message translates to:
  /// **'{name} hazır'**
  String addReady(String name);

  /// No description provided for @statLive.
  ///
  /// In tr, this message translates to:
  /// **'canlı kanal'**
  String get statLive;

  /// No description provided for @statMovies.
  ///
  /// In tr, this message translates to:
  /// **'film'**
  String get statMovies;

  /// No description provided for @statSeries.
  ///
  /// In tr, this message translates to:
  /// **'dizi'**
  String get statSeries;

  /// No description provided for @addAccountExpires.
  ///
  /// In tr, this message translates to:
  /// **'Hesap bitiş tarihi: {date}'**
  String addAccountExpires(String date);

  /// No description provided for @actionStart.
  ///
  /// In tr, this message translates to:
  /// **'Başla'**
  String get actionStart;

  /// No description provided for @onboardHint.
  ///
  /// In tr, this message translates to:
  /// **'Başlamak için bir kaynak ekleyin.'**
  String get onboardHint;

  /// No description provided for @onboardDisclaimer.
  ///
  /// In tr, this message translates to:
  /// **'Karadelik IPTV Player bir oynatıcıdır; kanal, film veya yayın sağlamaz ve satmaz. Yalnızca erişim hakkınız olan kaynakları ekleyin.'**
  String get onboardDisclaimer;

  /// No description provided for @setSources.
  ///
  /// In tr, this message translates to:
  /// **'Kaynaklar'**
  String get setSources;

  /// No description provided for @setPreferences.
  ///
  /// In tr, this message translates to:
  /// **'Tercihler'**
  String get setPreferences;

  /// No description provided for @setShortcuts.
  ///
  /// In tr, this message translates to:
  /// **'Kısayollar'**
  String get setShortcuts;

  /// No description provided for @setAbout.
  ///
  /// In tr, this message translates to:
  /// **'Hakkında'**
  String get setAbout;

  /// No description provided for @sourceAdd.
  ///
  /// In tr, this message translates to:
  /// **'Kaynak ekle'**
  String get sourceAdd;

  /// No description provided for @sourceNoneYet.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kaynak yok.'**
  String get sourceNoneYet;

  /// No description provided for @guideDownloading.
  ///
  /// In tr, this message translates to:
  /// **'Yayın akışı indiriliyor…'**
  String get guideDownloading;

  /// No description provided for @sourceDeleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'{name} silinsin mi?'**
  String sourceDeleteTitle(String name);

  /// No description provided for @sourceDeleteBody.
  ///
  /// In tr, this message translates to:
  /// **'Kaynağın kataloğu, favorileri ve izleme geçmişi bu bilgisayardan silinir. Şifre anahtar deposundan kaldırılır.'**
  String get sourceDeleteBody;

  /// No description provided for @actionDelete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get actionDelete;

  /// No description provided for @sourceActive.
  ///
  /// In tr, this message translates to:
  /// **'etkin'**
  String get sourceActive;

  /// No description provided for @sourceCounts.
  ///
  /// In tr, this message translates to:
  /// **'{live} kanal · {movies} film · {series} dizi'**
  String sourceCounts(int live, int movies, int series);

  /// No description provided for @guideButton.
  ///
  /// In tr, this message translates to:
  /// **'Yayın akışı'**
  String get guideButton;

  /// No description provided for @sourceActivate.
  ///
  /// In tr, this message translates to:
  /// **'Etkinleştir'**
  String get sourceActivate;

  /// No description provided for @guideNoUrl.
  ///
  /// In tr, this message translates to:
  /// **'Yayın akışı yok: liste bir XMLTV adresi bildirmiyor.'**
  String get guideNoUrl;

  /// No description provided for @guideNotYet.
  ///
  /// In tr, this message translates to:
  /// **'Yayın akışı henüz indirilmedi.'**
  String get guideNotYet;

  /// No description provided for @guideFailed.
  ///
  /// In tr, this message translates to:
  /// **'Yayın akışı alınamadı: {error}'**
  String guideFailed(String error);

  /// No description provided for @guideStatus.
  ///
  /// In tr, this message translates to:
  /// **'Yayın akışı: {matched} kanal eşleşti · {programmes} program · {ago}'**
  String guideStatus(String matched, String programmes, String ago);

  /// No description provided for @prefLanguage.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama dili'**
  String get prefLanguage;

  /// No description provided for @prefLanguageSystem.
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get prefLanguageSystem;

  /// No description provided for @prefRegion.
  ///
  /// In tr, this message translates to:
  /// **'Öne çıkan bölge'**
  String get prefRegion;

  /// No description provided for @prefRegionBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu bölgenin kategorileri ve kanalları her listede en başta gösterilir. Diğerleri sağlayıcının sırasıyla devam eder; yetişkin içerik her zaman en sondadır. Bölge, kategori adlarından okunur (ör. “TR: Ulusal”, “|DE| Sport”).'**
  String get prefRegionBody;

  /// No description provided for @prefOff.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı'**
  String get prefOff;

  /// No description provided for @prefRegionNone.
  ///
  /// In tr, this message translates to:
  /// **'Etkin kaynakta bölge etiketi bulunamadı; sıralama sağlayıcının kendi sırası olarak kalır.'**
  String get prefRegionNone;

  /// No description provided for @tmdbRemoved.
  ///
  /// In tr, this message translates to:
  /// **'Anahtar kaldırıldı.'**
  String get tmdbRemoved;

  /// No description provided for @tmdbSaved.
  ///
  /// In tr, this message translates to:
  /// **'Anahtar doğrulandı ve kaydedildi.'**
  String get tmdbSaved;

  /// No description provided for @tmdbTitle.
  ///
  /// In tr, this message translates to:
  /// **'TMDB içerik bilgileri'**
  String get tmdbTitle;

  /// No description provided for @tagOn.
  ///
  /// In tr, this message translates to:
  /// **'AÇIK'**
  String get tagOn;

  /// No description provided for @tagOff.
  ///
  /// In tr, this message translates to:
  /// **'KAPALI'**
  String get tagOff;

  /// No description provided for @tmdbBody.
  ///
  /// In tr, this message translates to:
  /// **'Film ve dizilerde özet, tür, oyuncu fotoğrafları, fragman, yaş sınırı ve bölüm bilgileri TMDB’den gelir. Anahtar yalnızca bu bilgisayarın anahtar deposunda saklanır; TMDB’ye yalnızca içerik adı ve yılı gönderilir.'**
  String get tmdbBody;

  /// No description provided for @tmdbReplaceHint.
  ///
  /// In tr, this message translates to:
  /// **'Yeni anahtar ile değiştir'**
  String get tmdbReplaceHint;

  /// No description provided for @tmdbKeyHint.
  ///
  /// In tr, this message translates to:
  /// **'API anahtarı (v3) veya okuma erişim jetonu (v4)'**
  String get tmdbKeyHint;

  /// No description provided for @tmdbVerify.
  ///
  /// In tr, this message translates to:
  /// **'Doğrula ve kaydet'**
  String get tmdbVerify;

  /// No description provided for @tmdbWhere.
  ///
  /// In tr, this message translates to:
  /// **'Anahtarı nereden alırım?'**
  String get tmdbWhere;

  /// No description provided for @tmdbWhereLink.
  ///
  /// In tr, this message translates to:
  /// **'themoviedb.org › Ayarlar › API'**
  String get tmdbWhereLink;

  /// No description provided for @tmdbLanguage.
  ///
  /// In tr, this message translates to:
  /// **'Bilgi dili'**
  String get tmdbLanguage;

  /// No description provided for @keySections.
  ///
  /// In tr, this message translates to:
  /// **'Ana sayfa, Canlı TV, Yayın akışı, Filmler, Diziler, Favoriler'**
  String get keySections;

  /// No description provided for @keyZap.
  ///
  /// In tr, this message translates to:
  /// **'Kanal değiştir'**
  String get keyZap;

  /// No description provided for @keyDigits.
  ///
  /// In tr, this message translates to:
  /// **'Kanal numarasıyla geç (Enter beklemeden açar)'**
  String get keyDigits;

  /// No description provided for @keyMediaKeys.
  ///
  /// In tr, this message translates to:
  /// **'Medya tuşları'**
  String get keyMediaKeys;

  /// No description provided for @keyMediaKeysDo.
  ///
  /// In tr, this message translates to:
  /// **'Oynat / duraklat, sonraki / önceki kanal (film ve dizide ileri / geri sarma)'**
  String get keyMediaKeysDo;

  /// No description provided for @keyPage.
  ///
  /// In tr, this message translates to:
  /// **'Listede 10 kanal atla'**
  String get keyPage;

  /// No description provided for @keyEnter.
  ///
  /// In tr, this message translates to:
  /// **'Tam ekran oynat'**
  String get keyEnter;

  /// No description provided for @keySeek.
  ///
  /// In tr, this message translates to:
  /// **'10 saniye geri / ileri (film ve dizi)'**
  String get keySeek;

  /// No description provided for @keyFKey.
  ///
  /// In tr, this message translates to:
  /// **'F, çift tık'**
  String get keyFKey;

  /// No description provided for @keyFullscreen.
  ///
  /// In tr, this message translates to:
  /// **'Pencereyi tam ekran yap'**
  String get keyFullscreen;

  /// No description provided for @keyTracks.
  ///
  /// In tr, this message translates to:
  /// **'Ses ve altyazı paneli'**
  String get keyTracks;

  /// No description provided for @keyChannelList.
  ///
  /// In tr, this message translates to:
  /// **'Oynatıcıda kanal listesi'**
  String get keyChannelList;

  /// No description provided for @keyMute.
  ///
  /// In tr, this message translates to:
  /// **'Sesi kapat / aç'**
  String get keyMute;

  /// No description provided for @keyEsc.
  ///
  /// In tr, this message translates to:
  /// **'Paneli kapat, oynatıcıdan çık'**
  String get keyEsc;

  /// No description provided for @aboutVersion.
  ///
  /// In tr, this message translates to:
  /// **'Sürüm {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutDisclaimer.
  ///
  /// In tr, this message translates to:
  /// **'Karadelik IPTV Player bir oynatıcıdır. Kanal, film veya yayın sağlamaz, satmaz ve barındırmaz. Eklediğiniz kaynakların yasal olduğundan ve erişim hakkınız bulunduğundan siz sorumlusunuz.'**
  String get aboutDisclaimer;

  /// No description provided for @aboutPrivacy.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik: kaynak şifreleri yalnızca bu bilgisayarın anahtar deposunda tutulur. Uygulama izleme veya reklam SDK’sı içermez.'**
  String get aboutPrivacy;

  /// No description provided for @aboutTmdb.
  ///
  /// In tr, this message translates to:
  /// **'Film ve dizi bilgileri, isteğe bağlı olarak, The Movie Database’den (TMDB) alınır.'**
  String get aboutTmdb;

  /// No description provided for @aboutLicenses.
  ///
  /// In tr, this message translates to:
  /// **'Açık kaynak lisansları'**
  String get aboutLicenses;

  /// No description provided for @errNoPicture.
  ///
  /// In tr, this message translates to:
  /// **'Yayından görüntü gelmedi'**
  String get errNoPicture;

  /// No description provided for @reasonStalled.
  ///
  /// In tr, this message translates to:
  /// **'Yayın takıldı'**
  String get reasonStalled;

  /// No description provided for @reasonError.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı hatası'**
  String get reasonError;

  /// No description provided for @reasonEnded.
  ///
  /// In tr, this message translates to:
  /// **'Yayın kesildi'**
  String get reasonEnded;

  /// No description provided for @trackN.
  ///
  /// In tr, this message translates to:
  /// **'Parça {n}'**
  String trackN(int n);

  /// No description provided for @trackForced.
  ///
  /// In tr, this message translates to:
  /// **'Zorunlu'**
  String get trackForced;

  /// No description provided for @trackExternal.
  ///
  /// In tr, this message translates to:
  /// **'Harici'**
  String get trackExternal;

  /// No description provided for @trackChannels.
  ///
  /// In tr, this message translates to:
  /// **'{n} kanal'**
  String trackChannels(int n);

  /// No description provided for @trackText.
  ///
  /// In tr, this message translates to:
  /// **'Metin'**
  String get trackText;

  /// No description provided for @mediaCatchup.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş yayın'**
  String get mediaCatchup;

  /// No description provided for @mediaSeries.
  ///
  /// In tr, this message translates to:
  /// **'Dizi'**
  String get mediaSeries;

  /// No description provided for @mediaMovie.
  ///
  /// In tr, this message translates to:
  /// **'Film'**
  String get mediaMovie;

  /// No description provided for @startupFailed.
  ///
  /// In tr, this message translates to:
  /// **'Kütüphane açılamadı'**
  String get startupFailed;

  /// No description provided for @startupDataDir.
  ///
  /// In tr, this message translates to:
  /// **'Veri klasörü: {dir}'**
  String startupDataDir(String dir);

  /// No description provided for @addServer.
  ///
  /// In tr, this message translates to:
  /// **'Sunucu adresi'**
  String get addServer;

  /// No description provided for @addServerHint.
  ///
  /// In tr, this message translates to:
  /// **'http://sunucu:8080'**
  String get addServerHint;

  /// No description provided for @addListUrl.
  ///
  /// In tr, this message translates to:
  /// **'Liste adresi'**
  String get addListUrl;

  /// No description provided for @addStalker.
  ///
  /// In tr, this message translates to:
  /// **'Stalker portalı'**
  String get addStalker;

  /// No description provided for @addNeedPortal.
  ///
  /// In tr, this message translates to:
  /// **'Portal adresini girin'**
  String get addNeedPortal;

  /// No description provided for @addNeedMac.
  ///
  /// In tr, this message translates to:
  /// **'MAC adresini 00:1A:79:12:34:56 biçiminde girin'**
  String get addNeedMac;

  /// No description provided for @addStalkerHint.
  ///
  /// In tr, this message translates to:
  /// **'Portal adresi ve MAC'**
  String get addStalkerHint;

  /// No description provided for @addPortal.
  ///
  /// In tr, this message translates to:
  /// **'Portal adresi'**
  String get addPortal;

  /// No description provided for @addMac.
  ///
  /// In tr, this message translates to:
  /// **'MAC adresi'**
  String get addMac;

  /// No description provided for @updTitle.
  ///
  /// In tr, this message translates to:
  /// **'Güncellemeler'**
  String get updTitle;

  /// No description provided for @updIdle.
  ///
  /// In tr, this message translates to:
  /// **'Sürüm {version}'**
  String updIdle(String version);

  /// No description provided for @updChecking.
  ///
  /// In tr, this message translates to:
  /// **'Denetleniyor…'**
  String get updChecking;

  /// No description provided for @updUpToDate.
  ///
  /// In tr, this message translates to:
  /// **'Güncelsiniz: {version} en yeni sürüm.'**
  String updUpToDate(String version);

  /// No description provided for @updAvailable.
  ///
  /// In tr, this message translates to:
  /// **'Yeni sürüm hazır: {version}'**
  String updAvailable(String version);

  /// No description provided for @updFailed.
  ///
  /// In tr, this message translates to:
  /// **'Denetlenemedi: {error}'**
  String updFailed(String error);

  /// No description provided for @updCheck.
  ///
  /// In tr, this message translates to:
  /// **'Güncellemeleri denetle'**
  String get updCheck;

  /// No description provided for @updDownload.
  ///
  /// In tr, this message translates to:
  /// **'İndir'**
  String get updDownload;

  /// No description provided for @updInstall.
  ///
  /// In tr, this message translates to:
  /// **'Kur ve yeniden başlat'**
  String get updInstall;

  /// No description provided for @updRollBack.
  ///
  /// In tr, this message translates to:
  /// **'{version} sürümüne dön'**
  String updRollBack(String version);

  /// No description provided for @updBadge.
  ///
  /// In tr, this message translates to:
  /// **'Güncelleme var'**
  String get updBadge;

  /// No description provided for @updBadgeReady.
  ///
  /// In tr, this message translates to:
  /// **'Güncelleme hazır'**
  String get updBadgeReady;

  /// No description provided for @railFilterHint.
  ///
  /// In tr, this message translates to:
  /// **'Kategorilerde ara'**
  String get railFilterHint;

  /// No description provided for @railNoMatch.
  ///
  /// In tr, this message translates to:
  /// **'Eşleşen kategori yok'**
  String get railNoMatch;

  /// No description provided for @guidePickCategory.
  ///
  /// In tr, this message translates to:
  /// **'Kategori'**
  String get guidePickCategory;

  /// No description provided for @historyClear.
  ///
  /// In tr, this message translates to:
  /// **'Temizle'**
  String get historyClear;

  /// No description provided for @historyClearAll.
  ///
  /// In tr, this message translates to:
  /// **'İzleme geçmişini temizle'**
  String get historyClearAll;

  /// No description provided for @historyClearBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu kaynağın son izlenen kanalları ve yarım kalan film/dizi kayıtları silinir. Favoriler kalır.'**
  String get historyClearBody;

  /// No description provided for @historyCleared.
  ///
  /// In tr, this message translates to:
  /// **'İzleme geçmişi temizlendi.'**
  String get historyCleared;

  /// No description provided for @historyTitle.
  ///
  /// In tr, this message translates to:
  /// **'İzleme geçmişi'**
  String get historyTitle;

  /// No description provided for @adjTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get adjTitle;

  /// No description provided for @adjSubtitleDelay.
  ///
  /// In tr, this message translates to:
  /// **'Altyazı gecikmesi'**
  String get adjSubtitleDelay;

  /// No description provided for @adjAudioDelay.
  ///
  /// In tr, this message translates to:
  /// **'Ses gecikmesi'**
  String get adjAudioDelay;

  /// No description provided for @adjSubtitleSize.
  ///
  /// In tr, this message translates to:
  /// **'Altyazı boyutu'**
  String get adjSubtitleSize;

  /// No description provided for @adjAspect.
  ///
  /// In tr, this message translates to:
  /// **'Görüntü oranı'**
  String get adjAspect;

  /// No description provided for @adjAspectAuto.
  ///
  /// In tr, this message translates to:
  /// **'Otomatik'**
  String get adjAspectAuto;

  /// No description provided for @adjAspectFill.
  ///
  /// In tr, this message translates to:
  /// **'Doldur'**
  String get adjAspectFill;

  /// No description provided for @adjSpeed.
  ///
  /// In tr, this message translates to:
  /// **'Oynatma hızı'**
  String get adjSpeed;

  /// No description provided for @adjSleep.
  ///
  /// In tr, this message translates to:
  /// **'Uyku zamanlayıcısı'**
  String get adjSleep;

  /// No description provided for @adjSleepOff.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı'**
  String get adjSleepOff;

  /// No description provided for @adjMinutes.
  ///
  /// In tr, this message translates to:
  /// **'{n} dk'**
  String adjMinutes(int n);

  /// No description provided for @adjSleepProgrammeEnd.
  ///
  /// In tr, this message translates to:
  /// **'Program bitince'**
  String get adjSleepProgrammeEnd;

  /// No description provided for @adjSleepTag.
  ///
  /// In tr, this message translates to:
  /// **'Uyku {time}'**
  String adjSleepTag(String time);

  /// No description provided for @adjAddSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Altyazı dosyası ekle…'**
  String get adjAddSubtitle;

  /// No description provided for @adjSubtitleFiles.
  ///
  /// In tr, this message translates to:
  /// **'Altyazı dosyaları'**
  String get adjSubtitleFiles;

  /// No description provided for @adjSubtitleDelayNote.
  ///
  /// In tr, this message translates to:
  /// **'Altyazı gecikmesi {value}'**
  String adjSubtitleDelayNote(String value);

  /// No description provided for @keySubtitleDelay.
  ///
  /// In tr, this message translates to:
  /// **'Altyazıyı 0,1 sn erken / geç göster'**
  String get keySubtitleDelay;

  /// No description provided for @statsTitle.
  ///
  /// In tr, this message translates to:
  /// **'İstatistikler'**
  String get statsTitle;

  /// No description provided for @tipStats.
  ///
  /// In tr, this message translates to:
  /// **'İstatistikler ve teşhis (I)'**
  String get tipStats;

  /// No description provided for @keyStats.
  ///
  /// In tr, this message translates to:
  /// **'İstatistikler: neden takılıyor?'**
  String get keyStats;

  /// No description provided for @actionClose.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get actionClose;

  /// No description provided for @statsVideo.
  ///
  /// In tr, this message translates to:
  /// **'Görüntü'**
  String get statsVideo;

  /// No description provided for @statsDecoder.
  ///
  /// In tr, this message translates to:
  /// **'Donanım çözme'**
  String get statsDecoder;

  /// No description provided for @statsSoftware.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı (işlemci)'**
  String get statsSoftware;

  /// No description provided for @statsBitrate.
  ///
  /// In tr, this message translates to:
  /// **'Görüntü bit hızı'**
  String get statsBitrate;

  /// No description provided for @statsAudio.
  ///
  /// In tr, this message translates to:
  /// **'Ses'**
  String get statsAudio;

  /// No description provided for @statsBuffer.
  ///
  /// In tr, this message translates to:
  /// **'Önbellek'**
  String get statsBuffer;

  /// No description provided for @statsDownload.
  ///
  /// In tr, this message translates to:
  /// **'İndirme hızı'**
  String get statsDownload;

  /// No description provided for @statsDropped.
  ///
  /// In tr, this message translates to:
  /// **'Atlanan kare'**
  String get statsDropped;

  /// No description provided for @statsOpen.
  ///
  /// In tr, this message translates to:
  /// **'Açılış süresi'**
  String get statsOpen;

  /// No description provided for @statsReconnects.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden bağlanma'**
  String get statsReconnects;

  /// No description provided for @statsCheckSource.
  ///
  /// In tr, this message translates to:
  /// **'Sağlayıcıyı kontrol et'**
  String get statsCheckSource;

  /// No description provided for @statsChecking.
  ///
  /// In tr, this message translates to:
  /// **'Kontrol ediliyor…'**
  String get statsChecking;

  /// No description provided for @statsAnswered.
  ///
  /// In tr, this message translates to:
  /// **'Sunucu yanıt verdi · {ms} ms'**
  String statsAnswered(int ms);

  /// No description provided for @statsNoAnswer.
  ///
  /// In tr, this message translates to:
  /// **'Sunucu yanıt vermedi'**
  String get statsNoAnswer;

  /// No description provided for @statsConnections.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı {active}/{max}'**
  String statsConnections(int active, int max);

  /// No description provided for @statsExpires.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş {date}'**
  String statsExpires(String date);

  /// No description provided for @findSourceDown.
  ///
  /// In tr, this message translates to:
  /// **'Sağlayıcı yanıt vermiyor: sorun büyük olasılıkla onların tarafında.'**
  String get findSourceDown;

  /// No description provided for @findAccountExpired.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın süresi dolmuş görünüyor.'**
  String get findAccountExpired;

  /// No description provided for @findConnectionLimit.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı sınırı dolu: hesap başka bir cihazda da açıksa yayın kesilebilir.'**
  String get findConnectionLimit;

  /// No description provided for @findSlowNetwork.
  ///
  /// In tr, this message translates to:
  /// **'İndirme hızı yayının bit hızına yetişmiyor: ağ ya da sağlayıcı yavaş.'**
  String get findSlowNetwork;

  /// No description provided for @findCacheLow.
  ///
  /// In tr, this message translates to:
  /// **'Önbellek neredeyse boş: kısa takılmalar olabilir.'**
  String get findCacheLow;

  /// No description provided for @findFramesDropping.
  ///
  /// In tr, this message translates to:
  /// **'Kareler atlanıyor: bilgisayar görüntüyü çözmeye yetişemiyor.'**
  String get findFramesDropping;

  /// No description provided for @findSoftwareDecoding.
  ///
  /// In tr, this message translates to:
  /// **'Donanım çözme kullanılmıyor; ekran kartı sürücüsünü güncellemek yardımcı olabilir.'**
  String get findSoftwareDecoding;

  /// No description provided for @findReconnected.
  ///
  /// In tr, this message translates to:
  /// **'Yayın bu kanalda kesilip yeniden bağlandı.'**
  String get findReconnected;

  /// No description provided for @findHealthy.
  ///
  /// In tr, this message translates to:
  /// **'Şu an bir sorun görünmüyor.'**
  String get findHealthy;

  /// No description provided for @actionWatch.
  ///
  /// In tr, this message translates to:
  /// **'İzle'**
  String get actionWatch;

  /// No description provided for @actionDismiss.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get actionDismiss;

  /// No description provided for @actionWatchChannelNow.
  ///
  /// In tr, this message translates to:
  /// **'Kanalı şimdi aç'**
  String get actionWatchChannelNow;

  /// No description provided for @reminderSet.
  ///
  /// In tr, this message translates to:
  /// **'Hatırlat'**
  String get reminderSet;

  /// No description provided for @reminderRemove.
  ///
  /// In tr, this message translates to:
  /// **'Hatırlatmayı kaldır'**
  String get reminderRemove;

  /// No description provided for @reminderStartsAt.
  ///
  /// In tr, this message translates to:
  /// **'{time} başlıyor'**
  String reminderStartsAt(String time);

  /// No description provided for @reminderStarted.
  ///
  /// In tr, this message translates to:
  /// **'Başladı'**
  String get reminderStarted;

  /// No description provided for @paletteHint.
  ///
  /// In tr, this message translates to:
  /// **'Komut, kanal, film veya dizi… (numara yazınca kanal açılır)'**
  String get paletteHint;

  /// No description provided for @paletteNothing.
  ///
  /// In tr, this message translates to:
  /// **'Eşleşen bir şey yok'**
  String get paletteNothing;

  /// No description provided for @paletteCommands.
  ///
  /// In tr, this message translates to:
  /// **'Komutlar'**
  String get paletteCommands;

  /// No description provided for @paletteChannelNumber.
  ///
  /// In tr, this message translates to:
  /// **'Kanal numarası'**
  String get paletteChannelNumber;

  /// No description provided for @paletteGoTo.
  ///
  /// In tr, this message translates to:
  /// **'Git'**
  String get paletteGoTo;

  /// No description provided for @paletteFullPlayer.
  ///
  /// In tr, this message translates to:
  /// **'Oynatıcıyı tam aç'**
  String get paletteFullPlayer;

  /// No description provided for @paletteStop.
  ///
  /// In tr, this message translates to:
  /// **'Oynatmayı durdur'**
  String get paletteStop;

  /// No description provided for @paletteSwitchSource.
  ///
  /// In tr, this message translates to:
  /// **'Kaynağa geç: {name}'**
  String paletteSwitchSource(String name);

  /// No description provided for @paletteLanguage.
  ///
  /// In tr, this message translates to:
  /// **'Arayüz dili'**
  String get paletteLanguage;

  /// No description provided for @paletteUpdates.
  ///
  /// In tr, this message translates to:
  /// **'Güncellemeler ve sürüm'**
  String get paletteUpdates;

  /// No description provided for @paletteAddSource.
  ///
  /// In tr, this message translates to:
  /// **'Kaynak ekle veya düzenle'**
  String get paletteAddSource;

  /// No description provided for @timeshiftGoLive.
  ///
  /// In tr, this message translates to:
  /// **'Canlıya dön'**
  String get timeshiftGoLive;

  /// No description provided for @prefTimeshift.
  ///
  /// In tr, this message translates to:
  /// **'Canlı yayını durdurma ve geri sarma'**
  String get prefTimeshift;

  /// No description provided for @prefTimeshiftBody.
  ///
  /// In tr, this message translates to:
  /// **'Sağlayıcı arşiv sunmasa da canlı kanalı durdurup geri sarabilmeniz için son dakikalar diskte geçici bir dosyada tutulur; kanal değişince ve uygulama kapanınca silinir. Süre, yayının bit hızına göre değişir (5 Mbit/s HD için tahmin).'**
  String get prefTimeshiftBody;

  /// No description provided for @prefTimeshiftMinutes.
  ///
  /// In tr, this message translates to:
  /// **'≈{n} dk'**
  String prefTimeshiftMinutes(int n);

  /// No description provided for @pinTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ebeveyn kilidi'**
  String get pinTitle;

  /// No description provided for @pinBodyOff.
  ///
  /// In tr, this message translates to:
  /// **'Bir PIN belirlediğinizde yetişkin kategorileri ve içerikleri listelerden, aramadan ve ana sayfadan gizlenir; PIN girilince görünür. Uygulama her açılışta yeniden kilitlenir.'**
  String get pinBodyOff;

  /// No description provided for @pinBodyLocked.
  ///
  /// In tr, this message translates to:
  /// **'Kilitli: yetişkin içerik gizli.'**
  String get pinBodyLocked;

  /// No description provided for @pinBodyOpen.
  ///
  /// In tr, this message translates to:
  /// **'Kilit açık: yetişkin içerik görünüyor. Uygulama kapanınca yeniden kilitlenir.'**
  String get pinBodyOpen;

  /// No description provided for @pinSet.
  ///
  /// In tr, this message translates to:
  /// **'PIN belirle'**
  String get pinSet;

  /// No description provided for @pinUnlock.
  ///
  /// In tr, this message translates to:
  /// **'Kilidi aç'**
  String get pinUnlock;

  /// No description provided for @pinLockNow.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi kilitle'**
  String get pinLockNow;

  /// No description provided for @pinChange.
  ///
  /// In tr, this message translates to:
  /// **'PIN\'i değiştir'**
  String get pinChange;

  /// No description provided for @pinRemove.
  ///
  /// In tr, this message translates to:
  /// **'PIN\'i kaldır'**
  String get pinRemove;

  /// No description provided for @pinOk.
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get pinOk;

  /// No description provided for @pinUnlockTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ebeveyn kilidi'**
  String get pinUnlockTitle;

  /// No description provided for @pinUnlockBody.
  ///
  /// In tr, this message translates to:
  /// **'Yetişkin içeriği göstermek için PIN\'i girin.'**
  String get pinUnlockBody;

  /// No description provided for @pinCurrentTitle.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut PIN'**
  String get pinCurrentTitle;

  /// No description provided for @pinCurrentBody.
  ///
  /// In tr, this message translates to:
  /// **'Devam etmek için mevcut PIN\'i girin.'**
  String get pinCurrentBody;

  /// No description provided for @pinNewTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni PIN'**
  String get pinNewTitle;

  /// No description provided for @pinNewBody.
  ///
  /// In tr, this message translates to:
  /// **'4-6 rakamlı bir PIN seçin.'**
  String get pinNewBody;

  /// No description provided for @pinRepeatTitle.
  ///
  /// In tr, this message translates to:
  /// **'PIN\'i tekrarlayın'**
  String get pinRepeatTitle;

  /// No description provided for @pinRepeatBody.
  ///
  /// In tr, this message translates to:
  /// **'Aynı PIN\'i bir kez daha girin.'**
  String get pinRepeatBody;

  /// No description provided for @pinRemoveTitle.
  ///
  /// In tr, this message translates to:
  /// **'PIN\'i kaldır'**
  String get pinRemoveTitle;

  /// No description provided for @pinWrong.
  ///
  /// In tr, this message translates to:
  /// **'PIN yanlış'**
  String get pinWrong;

  /// No description provided for @pinMismatch.
  ///
  /// In tr, this message translates to:
  /// **'PIN\'ler aynı değil'**
  String get pinMismatch;

  /// No description provided for @pinTooShort.
  ///
  /// In tr, this message translates to:
  /// **'En az 4 rakam'**
  String get pinTooShort;

  /// No description provided for @pinLockedCategories.
  ///
  /// In tr, this message translates to:
  /// **'Kilitli kategoriler'**
  String get pinLockedCategories;

  /// No description provided for @editRename.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden adlandır…'**
  String get editRename;

  /// No description provided for @editRenameChannel.
  ///
  /// In tr, this message translates to:
  /// **'Kanalı yeniden adlandır'**
  String get editRenameChannel;

  /// No description provided for @editRenameCategory.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriyi yeniden adlandır'**
  String get editRenameCategory;

  /// No description provided for @editRenameGroup.
  ///
  /// In tr, this message translates to:
  /// **'Grubu yeniden adlandır'**
  String get editRenameGroup;

  /// No description provided for @editOriginalName.
  ///
  /// In tr, this message translates to:
  /// **'Sağlayıcıdaki adı: {name}'**
  String editOriginalName(String name);

  /// No description provided for @editResetName.
  ///
  /// In tr, this message translates to:
  /// **'Özgün ada dön'**
  String get editResetName;

  /// No description provided for @editMoveUp.
  ///
  /// In tr, this message translates to:
  /// **'Yukarı taşı'**
  String get editMoveUp;

  /// No description provided for @editMoveDown.
  ///
  /// In tr, this message translates to:
  /// **'Aşağı taşı'**
  String get editMoveDown;

  /// No description provided for @editHideCategory.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriyi gizle'**
  String get editHideCategory;

  /// No description provided for @editHideChannel.
  ///
  /// In tr, this message translates to:
  /// **'Kanalı gizle'**
  String get editHideChannel;

  /// No description provided for @editDeleteGroup.
  ///
  /// In tr, this message translates to:
  /// **'Grubu sil'**
  String get editDeleteGroup;

  /// No description provided for @editRemoveFromGroup.
  ///
  /// In tr, this message translates to:
  /// **'Gruptan çıkar'**
  String get editRemoveFromGroup;

  /// No description provided for @editAddToGroup.
  ///
  /// In tr, this message translates to:
  /// **'{name} grubuna ekle'**
  String editAddToGroup(String name);

  /// No description provided for @editNewGroup.
  ///
  /// In tr, this message translates to:
  /// **'Yeni gruba ekle…'**
  String get editNewGroup;

  /// No description provided for @editNewGroupTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni grup'**
  String get editNewGroupTitle;

  /// No description provided for @editShow.
  ///
  /// In tr, this message translates to:
  /// **'Göster'**
  String get editShow;

  /// No description provided for @editHiddenTitle.
  ///
  /// In tr, this message translates to:
  /// **'Gizlenen kanallar ve kategoriler'**
  String get editHiddenTitle;

  /// No description provided for @editHiddenNone.
  ///
  /// In tr, this message translates to:
  /// **'Gizlenen bir şey yok. Kanal veya kategori listesinde sağ tıklayarak gizleyebilir, yeniden adlandırabilir ya da kendi gruplarınızı kurabilirsiniz; eşitlemeden sonra da kalırlar.'**
  String get editHiddenNone;

  /// No description provided for @editHiddenBody.
  ///
  /// In tr, this message translates to:
  /// **'Bunlar listelerde ve aramada görünmez; eşitlemeden sonra da gizli kalır.'**
  String get editHiddenBody;

  /// No description provided for @epgMenu.
  ///
  /// In tr, this message translates to:
  /// **'Yayın akışı ayarı…'**
  String get epgMenu;

  /// No description provided for @epgSettingsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yayın akışı: {name}'**
  String epgSettingsTitle(String name);

  /// No description provided for @epgShift.
  ///
  /// In tr, this message translates to:
  /// **'Saat kaydırma'**
  String get epgShift;

  /// No description provided for @epgShiftBody.
  ///
  /// In tr, this message translates to:
  /// **'Programlar gerçek saatinden önce ya da sonra görünüyorsa kaydırın. Geçmiş yayınlar da düzeltilmiş saatlerle açılır.'**
  String get epgShiftBody;

  /// No description provided for @epgShiftNone.
  ///
  /// In tr, this message translates to:
  /// **'Kaydırma yok'**
  String get epgShiftNone;

  /// No description provided for @epgHours.
  ///
  /// In tr, this message translates to:
  /// **'{n} sa'**
  String epgHours(int n);

  /// No description provided for @epgMinutes.
  ///
  /// In tr, this message translates to:
  /// **'{n} dk'**
  String epgMinutes(int n);

  /// No description provided for @epgMatch.
  ///
  /// In tr, this message translates to:
  /// **'Eşleşen yayın akışı kanalı'**
  String get epgMatch;

  /// No description provided for @epgAuto.
  ///
  /// In tr, this message translates to:
  /// **'Otomatik'**
  String get epgAuto;

  /// No description provided for @epgNoGuideShort.
  ///
  /// In tr, this message translates to:
  /// **'Yayın akışı yok'**
  String get epgNoGuideShort;

  /// No description provided for @epgAutoMatched.
  ///
  /// In tr, this message translates to:
  /// **'Otomatik: {name}'**
  String epgAutoMatched(String name);

  /// No description provided for @epgAutoNone.
  ///
  /// In tr, this message translates to:
  /// **'Otomatik eşleşme bulunamadı; aşağıdan seçebilirsiniz.'**
  String get epgAutoNone;

  /// No description provided for @epgNoGuide.
  ///
  /// In tr, this message translates to:
  /// **'Bu kanalda yayın akışı gösterilmiyor.'**
  String get epgNoGuide;

  /// No description provided for @epgPicked.
  ///
  /// In tr, this message translates to:
  /// **'Elle seçildi: {name}'**
  String epgPicked(String name);

  /// No description provided for @epgFindHint.
  ///
  /// In tr, this message translates to:
  /// **'Yayın akışında kanal ara'**
  String get epgFindHint;

  /// No description provided for @epgSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get epgSave;

  /// No description provided for @backupTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yedekleme ve geri yükleme'**
  String get backupTitle;

  /// No description provided for @backupBody.
  ///
  /// In tr, this message translates to:
  /// **'Kaynaklarınız (şifreleriyle), favorileriniz, izleme geçmişiniz, gizlediğiniz ve yeniden adlandırdığınız kanallar, gruplarınız, yayın akışı düzeltmeleri, hatırlatmalar ve ayarlar tek bir dosyaya, seçtiğiniz parolayla şifrelenerek yazılır. Parola olmadan açılamaz; unutursanız kurtarılamaz. Kanal listeleri dosyada yoktur, geri yüklemeden sonra eşitlenir.'**
  String get backupBody;

  /// No description provided for @backupExport.
  ///
  /// In tr, this message translates to:
  /// **'Yedek al…'**
  String get backupExport;

  /// No description provided for @backupImport.
  ///
  /// In tr, this message translates to:
  /// **'Yedekten geri yükle…'**
  String get backupImport;

  /// No description provided for @backupSaved.
  ///
  /// In tr, this message translates to:
  /// **'Yedek kaydedildi: {sources} kaynak, {favorites} favori, {groups} grup.'**
  String backupSaved(int sources, int favorites, int groups);

  /// No description provided for @backupRestored.
  ///
  /// In tr, this message translates to:
  /// **'Geri yüklendi: {sources} kaynak, {favorites} favori, {groups} grup.'**
  String backupRestored(int sources, int favorites, int groups);

  /// No description provided for @backupSyncing.
  ///
  /// In tr, this message translates to:
  /// **'Kaynaklar eşitleniyor ({n}/{total})…'**
  String backupSyncing(int n, int total);

  /// No description provided for @backupPasswordNew.
  ///
  /// In tr, this message translates to:
  /// **'Yedek parolası'**
  String get backupPasswordNew;

  /// No description provided for @backupPasswordNewBody.
  ///
  /// In tr, this message translates to:
  /// **'Yedeği açmak için gerekecek. En az 8 karakter; unutulursa yedek açılamaz.'**
  String get backupPasswordNewBody;

  /// No description provided for @backupPasswordAsk.
  ///
  /// In tr, this message translates to:
  /// **'Yedeğin parolası'**
  String get backupPasswordAsk;

  /// No description provided for @backupPasswordAskBody.
  ///
  /// In tr, this message translates to:
  /// **'Yedeği alırken seçtiğiniz parola.'**
  String get backupPasswordAskBody;

  /// No description provided for @backupPassword.
  ///
  /// In tr, this message translates to:
  /// **'Parola'**
  String get backupPassword;

  /// No description provided for @backupPasswordAgain.
  ///
  /// In tr, this message translates to:
  /// **'Parola (tekrar)'**
  String get backupPasswordAgain;

  /// No description provided for @backupPasswordShort.
  ///
  /// In tr, this message translates to:
  /// **'En az 8 karakter'**
  String get backupPasswordShort;

  /// No description provided for @backupPasswordMismatch.
  ///
  /// In tr, this message translates to:
  /// **'Parolalar aynı değil'**
  String get backupPasswordMismatch;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
