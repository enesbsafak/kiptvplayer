# Karadelik IPTV Player

Windows (sonra macOS ve mobil) için hızlı, native hisli IPTV oynatıcı. KaradelikDev tasarım dili, Türkçe ve İngilizce.
İçerik sağlamaz; kullanıcı kendi yetkili kaynağını ekler (Xtream, M3U, Stalker portalı).

## Yapı

| Klasör | İçerik |
|---|---|
| `apps/desktop` | Flutter uygulaması (arayüz, oynatıcı, pencere, dil dosyaları `lib/l10n`) |
| `core/crates/kp-core` | Rust veri çekirdeği: Xtream / M3U / Stalker, SQLite + FTS5, XMLTV, catch-up, TMDB, güncelleyici, anahtar deposu |
| `core/crates/kp-bridge` | flutter_rust_bridge yüzeyi (`apps/desktop/lib/src/rust` buradan üretilir) |
| `packages/karadelik_mpv_libs` | SHA-256 doğrulamalı LGPL libmpv + ANGLE (media_kit_libs_video yerine) |
| `tools/mock-iptv` | Yerel test sağlayıcısı: Xtream, M3U + XMLTV, Stalker portalı, TMDB ve OpenSubtitles taklidi, test yayınları |
| `tools/installer` | Inno Setup betiği (kullanıcı bazlı kurulum) |
| `design/ui-spec.md` | Tasarım kararları ve kaynakları |
| `THIRD_PARTY.md` | Üçüncü taraf bileşenler ve lisans yükümlülükleri |

## Geliştirme

```powershell
# Bir kez: test yayınları ve görseller (-Audio: sesli, elle deneme için)
tools\mock-iptv\make-media.ps1; tools\mock-iptv\make-art.ps1

# Çekirdek testleri
cargo test --workspace
cargo run -p mock-iptv --release -- 8089          # ayrı terminalde
cargo test -p kp-core --test xtream_mock -- --ignored --test-threads=1

# Köprü kodu (Rust API değişince) ve dil dosyaları
cd apps\desktop; flutter_rust_bridge_codegen generate; flutter gen-l10n

# Uygulama
cd apps\desktop; flutter test; flutter build windows --release
tools\demo.ps1                    # normal pencerede, demo kaynağıyla
tools\shots.ps1 [-Language en]    # ekran dışı, sessiz: tüm ekranların PNG'si
```

Otomatik çalıştırmalar `--kp-offscreen` ile pencereyi ekran dışında açar, odak almaz, ses cihazı açmaz,
medya kontrollerine görünmez ve şifreleri işletim sisteminin anahtar deposuna değil belleğe yazar.

## Sürüm çıkarma

```powershell
# tools\release-notes\<sürüm>.tr.txt / .en.txt: güncelleme penceresinde görünen notlar
tools\release.ps1 -Version 0.2.0      # dist\: kurulum dosyası + latest.json
```

- `v0.2.0` etiketi gönderilince GitHub Actions (`.github/workflows/release.yml`) aynısını yapar ve GitHub sürümü olarak yayınlar.
- Uygulama içi güncelleyici `latest.json`'u okur, kurulumu indirir, SHA-256'yı doğrular, sessiz kurar ve uygulamayı yeniden açar; bir önceki kurulum saklanır, “önceki sürüme dön” mümkündür.
- **Herkese açık indirme:** bu depo özel olduğundan güncelleyici sürümlerini okuyamaz. Yalnızca sürümleri tutan herkese açık bir depo `enesbsafak/kiptvplayer-releases` üzerinden yayınlanır: bu depoda `KP_RELEASES_REPO` değişkeni tanımlı; `KP_RELEASES_TOKEN` sırrı (o depoda Contents: okuma-yazma yetkili ince ayarlı token) eklenince kurulum, `latest.json` ve uygulamaya gömülen besleme adresi oraya yönelir. Değişken yoksa sürümler burada kalır.
- **İmza:** `KP_SIGN_CMD` ortam değişkeni / depo sırrı (ör. Azure Trusted Signing) tanımlıysa exe ve kurulum imzalanır; yoksa imzasızdır ve SmartScreen uyarır.
- **Yerel bağımlılıklar:** libmpv/ANGLE arşivleri `native-deps` sürümünde (özel depo) aynalanıyor; kaynak adres silinirse derleme oradan indirir (`gh` bu depoya erişebilen hesapla oturum açmış olmalı: `gh auth switch --user enesbsafak`, CI'da otomatik).
- **Yayın öncesi yapılacaklar:** GitHub deposu ve sürümleri (güncelleme adresi `enesbsafak/kiptvplayer` varsayılıyor; `--dart-define=KP_UPDATE_FEED=...` ile değişir), imza sertifikası, libmpv arşivinin kendi sürümümüze aynalanması (kaynak 30 gün saklıyor; `packages/karadelik_mpv_libs/manifest.json`).

## Fazlar

| Faz | Kapsam | Durum |
|---|---|---|
| M0 Deneme | Flutter + media_kit + kendi libmpv, Rust çekirdek, ölçüm altyapısı | ✓ Soğuk açılış ~0.5 sn, ilk kare ~0.3 sn, kanal değiştirme < 0.1 sn (yerel). Snap Layouts. LGPL libmpv. |
| M1 Temel | Tasarım sistemi, kabuk, kaynak ekleme, SQLite katalog, anahtar deposu, dil | ✓ TR/EN, tek örnek. Açık: tray |
| M2 Canlı + oynatıcı | Önizleme, OSD, zap, ses/altyazı, mini oynatıcı, favoriler | ✓ Yedek yayına geçme, numarayla kanal, medya tuşları (SMTC), ayırt edilebilir ses/altyazı listesi. Açık: 4 saatlik uzun süre testi |
| M3 EPG + catch-up | XMLTV, eşleştirme, grid, catch-up | ✓ XMLTV (250 MB rehber 3.4 sn, 53 MB bellek), tvg-id/ad eşleştirme, tvg-shift, catch-up (Xtream + M3U), kanal başına elle eşleştirme ve saat kaydırma, program hatırlatmaları |
| M4 VOD / arama / Stalker / TMDB | Film/dizi, devam et, arama, Stalker, TMDB | ✓ Stalker canlı TV ve filmler, TMDB (anahtar ayarlardan). Açık: Stalker dizileri |
| M4+ Rakip farkları | Yerel zaman kaydırma, liste düzenleme, kilit, yedek, araçlar | ✓ Canlı yayını durdurma/geri sarma (disk tamponu), kanal gizleme/adlandırma, kategori sırası, kendi gruplar, ebeveyn PIN'i, şifreli yedek/geri yükleme (Argon2id + XChaCha20-Poly1305), istatistik ve "neden donuyor" paneli, oynatıcı ayarları (gecikme, boyut, oran, hız, uyku), Ctrl+K komut paleti, OpenSubtitles araması |
| M5 Yayın | Güncelleyici, kurulum, imza, CI | ◐ Güncelleyici, Inno kurulum, CI ve sürüm iş akışı hazır. Açık: imza sertifikası, GitHub deposu, çökme raporu |

## Bilinen sorunlar

- **Kanal değişimi başına ~0.7 MB bellek geri verilmiyor** (tools/soak.ps1: 60 dk, dakikada bir kanal değişimi → 522 → 569 MB; 8 dk, 10 sn'de bir → +31 MB). Çökme yok, kapanış temiz. Dart tarafındaki önbellekler (media_kit `Media` önbelleği, EPG, resimler) sınırlı; şüpheli mpv/FFmpeg'in açılış başına yerel ayırmaları (donanım kod çözücü havuzu). Sonraki adım: UMDH (Windows Debugging Tools) ile yerel yığın karşılaştırması.
- **Zaman kaydırma tamponu diske yazar**: canlı kanal izlenirken yayın, seçilen boyuta kadar (varsayılan 2 GB) veri klasöründeki `timeshift` altına geçici olarak yazılır; kanal değişince ve kapanışta silinir. Tercihler'den kapatılabilir.
- **Ebeveyn PIN'i ekranı korur, dosyayı değil**: PIN tuzlu ve özetlenmiş saklanır, art arda 5 yanlış denemeden sonra 30 sn beklenir; ama 4-6 haneli bir kod, kütüphane dosyasına erişen birine karşı koruma değildir.
