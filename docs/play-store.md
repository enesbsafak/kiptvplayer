# Google Play listing and forms

Everything Play Console asks for, ready to paste. English (United States) is
the default language; Turkish is added as a translation.

Package: `dev.karadelik.player` · Category: Video Players & Editors · Free,
no ads, no in-app purchases.

## Graphics

`tools/store-graphics.py` builds them from real captures of the app with the
mock provider's test data (see the script's header):

- App icon 512x512: `icon-512.png`
- Feature graphic 1024x500: `feature-graphic-en.png`, `feature-graphic-tr.png`
- Phone screenshots 1080x1920: `android/en/*.png`, `android/tr/*.png`
- App Store 6.9" (1290x2796), for later: `ios/en`, `ios/tr`

No real channel names, logos, sports or films appear anywhere: the stores
remove IPTV apps whose listings suggest bundled content.

## Store listing: English

**App name** (30): `Karadelik Player`

**Short description** (80):
`Fast player for your own Xtream, M3U and Stalker sources. No content included.`

**Full description** (4000):

```
Karadelik Player is a fast, clean player for the IPTV sources you already have. It provides no channels, playlists or subscriptions: add a source you are entitled to use and the app takes care of the rest.

SOURCES
• Xtream Codes (server, username and password)
• M3U playlists from a link or a file, with XMLTV guides
• Stalker portals

LIVE TV
• Channel lists that open instantly from the local library
• Pause and rewind live TV with on-device timeshift
• Catch-up for channels whose provider offers it
• Favourites, custom groups, hidden and renamed channels

TV GUIDE
• A readable guide grid with now and next
• XMLTV matching, per-channel time shift and programme reminders

MOVIES AND SERIES
• Resume where you left off
• Search that ignores accents
• Optional details and artwork from TMDB with your own API key
• Subtitle search through OpenSubtitles with your own API key

PRIVATE BY DESIGN
• No account, no ads, no tracking, no analytics
• Passwords stay on your device, encrypted with a key held by the Android Keystore
• Encrypted backups when you ask for one

Open source (MPL-2.0): https://github.com/enesbsafak/kiptvplayer

Karadelik Player does not provide any content. Use it only with sources you have the right to access.
```

## Store listing: Turkish (tr-TR)

**Uygulama adı**: `Karadelik Player`

**Kısa açıklama**:
`Kendi Xtream, M3U ve Stalker kaynaklarınız için hızlı oynatıcı. İçerik içermez.`

**Tam açıklama**:

```
Karadelik Player, zaten sahip olduğunuz IPTV kaynakları için hızlı ve sade bir oynatıcıdır. Kanal, liste veya abonelik sağlamaz: kullanma hakkınız olan bir kaynağı ekleyin, gerisini uygulama halleder.

KAYNAKLAR
• Xtream Codes (sunucu, kullanıcı adı ve şifre)
• Bağlantıdan veya dosyadan M3U listeleri, XMLTV yayın akışıyla
• Stalker portalları

CANLI TV
• Yerel kütüphaneden anında açılan kanal listeleri
• Cihazda zaman kaydırma ile canlı yayını durdurma ve geri sarma
• Sağlayıcı sunuyorsa geçmiş yayınlar
• Favoriler, kendi gruplarınız, gizlenen ve yeniden adlandırılan kanallar

YAYIN AKIŞI
• Şimdi ve sonra ile okunaklı yayın akışı
• XMLTV eşleştirme, kanal başına saat kaydırma ve program hatırlatmaları

FİLM VE DİZİLER
• Kaldığınız yerden devam
• Türkçe karakterleri dert etmeyen arama
• İsteğe bağlı TMDB ayrıntıları ve görselleri (kendi API anahtarınızla)
• OpenSubtitles ile altyazı arama (kendi API anahtarınızla)

GİZLİLİK ÖNCELİKLİ
• Hesap, reklam, takip ve analiz yok
• Şifreler cihazınızda, Android Keystore'daki anahtarla şifreli olarak kalır
• İstediğinizde şifreli yedek

Açık kaynak (MPL-2.0): https://github.com/enesbsafak/kiptvplayer

Karadelik Player herhangi bir içerik sağlamaz. Yalnızca erişim hakkınız olan kaynaklarla kullanın.
```

## App content (Policy > App content)

| Form | Answer |
|---|---|
| Privacy policy | `https://github.com/enesbsafak/kiptvplayer/blob/main/docs/privacy.md` |
| Ads | No, the app does not contain ads |
| App access | All or some functionality is restricted: see "Instructions for reviewers" below |
| Content rating | Questionnaire, category "All other app types": no violence, sexuality, language, controlled substances or gambling in the app itself; user-generated content: No; users can interact: No; shares location: No; digital purchases: No. Note: the app plays what the user's own source provides. |
| Target audience | 18 and over (the user's sources are not controlled by the app) |
| News app | No |
| COVID-19 contact tracing | No |
| Data safety | Collects no data; shares no data. Data encrypted in transit: Yes (where the user's source supports HTTPS). Users can request deletion: data never leaves the device; uninstalling deletes it. |
| Government app | No |
| Financial features | None |
| Health | No |

## Instructions for reviewers (App access)

```
The app is a player only and ships with no content. To test it, add this
public demo playlist of free test streams (Apple HLS test streams and the
Blender Foundation's open films):

1. Open the app, choose "M3U link".
2. Playlist URL: https://raw.githubusercontent.com/enesbsafak/kiptvplayer/main/docs/review/demo.m3u
3. Tap "Connect and sync", then open Live TV and tap a channel.
```

## Release flow

1. First bundle by hand: Actions > Android release > Run workflow, download
   the `android-bundle` artifact, upload it in Testing > Internal testing.
2. Then every `v1.2.3` tag uploads to internal testing by itself once the
   `PLAY_SERVICE_ACCOUNT_JSON` secret is set (`.github/workflows/android-release.yml`).
3. Personal developer accounts created after 13 November 2023 need a closed
   test with at least 12 testers for 14 days before production access.
