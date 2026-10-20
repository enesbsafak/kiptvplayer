# Karadelik IPTV Player

Windows (sonra macOS ve mobil) için hızlı, native hisli IPTV oynatıcı. KaradelikDev tasarım dili.
İçerik sağlamaz; kullanıcı kendi yetkili kaynağını ekler.

## Yapı

| Klasör | İçerik |
|---|---|
| `apps/desktop` | Flutter uygulaması (arayüz, oynatıcı, pencere) |
| `core/crates/kp-core` | Rust veri çekirdeği: M3U/Xtream, SQLite + FTS5, EPG önbelleği, anahtar deposu |
| `core/crates/kp-bridge` | flutter_rust_bridge yüzeyi (`apps/desktop/lib/src/rust` buradan üretilir) |
| `packages/karadelik_mpv_libs` | SHA-256 doğrulamalı libmpv + ANGLE (media_kit_libs_video yerine) |
| `tools/mock-iptv` | Yerel test sağlayıcısı: Xtream API, M3U, test yayınları |
| `design/ui-spec.md` | Tasarım kararları ve kaynakları |

## Geliştirme

```powershell
# Bir kez: test yayınları ve görseller
tools\mock-iptv\make-media.ps1; tools\mock-iptv\make-art.ps1

# Çekirdek testleri
cargo test -p kp-core
cargo run -p mock-iptv --release -- 8089          # ayrı terminalde
cargo test -p kp-core --test xtream_mock -- --ignored

# Köprü kodu (Rust API değişince)
cd apps\desktop; flutter_rust_bridge_codegen generate

# Uygulama
cd apps\desktop; flutter build windows --release
tools\demo.ps1     # normal pencerede, demo kaynağıyla
tools\shots.ps1    # ekran dışı, sessiz: tüm ekranların PNG'si
```

Otomatik çalıştırmalar `--kp-offscreen` ile pencereyi ekran dışında açar, odak almaz, ses cihazı açmaz.

## Fazlar

| Faz | Kapsam | Durum |
|---|---|---|
| M0 Deneme | Flutter + media_kit + kendi libmpv, Rust çekirdek, ölçüm altyapısı | ✓ Hedefler tuttu (soğuk açılış ~0.4 sn, ilk kare ~0.3 sn, kanal değiştirme p90 < 0.1 sn yerelde). Açık: Snap Layouts, LGPL libmpv derlemesi |
| M1 Temel | Tasarım sistemi, kabuk, kaynak ekleme, SQLite katalog, anahtar deposu | ✓ Çoğu yapıldı. Açık: tek örnek (single instance), tray, TR/EN dil dosyaları |
| M2 Canlı + oynatıcı | Önizleme, tam ekran OSD, zap, ses/altyazı, mini oynatıcı, favoriler | ✓ Temel akış var. Açık: yayın yedeği (failover), medya tuşları (SMTC), uzun süreli test |
| M3 EPG + catch-up | XMLTV akış ayrıştırma, eşleştirme, grid, catch-up | ◐ Xtream kısa EPG + grid; catch-up (Xtream timeshift panel saat diliminde, M3U şablonları), geçmiş yayın listesi, rehberde geriye gitme. Açık: XMLTV, M3U için geçmiş program listesi |
| M4 VOD / arama / Stalker | Film/dizi detay, devam et, arama, Stalker | ◐ Detay, bölümler, devam et, arama var. Açık: Stalker, TMDB |
| M5 Yayın | Güncelleyici, imzalı kurulum, çökme raporu, CI | ☐ |
