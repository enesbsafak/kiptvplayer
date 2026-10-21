# Karadelik IPTV Player

Windows (sonra macOS ve mobil) için hızlı, native hisli IPTV oynatıcı. KaradelikDev tasarım dili, Türkçe ve İngilizce.
İçerik sağlamaz; kullanıcı kendi yetkili kaynağını ekler (Xtream, M3U, Stalker portalı).

Açık kaynak, [MPL-2.0](LICENSE). İndirme: [Releases](https://github.com/enesbsafak/kiptvplayer/releases).

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
- **İndirme:** sürümler bu deponun [Releases](https://github.com/enesbsafak/kiptvplayer/releases) sayfasından yayınlanır; güncelleyici `releases/latest/download/latest.json` adresini okur. `native-deps` ön sürümü yalnızca derleme bağımlılıklarını tutar, "latest" sayılmaz.
- **İmza:** `KP_SIGN_CMD` ortam değişkeni / depo sırrı (ör. Azure Trusted Signing) tanımlıysa exe ve kurulum imzalanır; yoksa imzasızdır ve SmartScreen uyarır.
- **Yerel bağımlılıklar:** libmpv/ANGLE arşivleri ve LGPL kaynakları `native-deps` sürümünde aynalanır; upstream adres silinirse derleme oradan indirir (giriş gerekmez).
- **Açık:** imza sertifikası.

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

- **Bellek, kanal değişimi:** sızıntı yok. Bellek oynayan kanala göre ±200 MB oynar (4K yayın 720p'den fazla çözücü ve önbellek tamponu tutar); bu yüzden tek tek örnekler yanıltır. `tools/soak.ps1` artık her beşte birlik dilimdeki en düşük değeri (tabanı) karşılaştırır. 20 dk, 5 sn'de bir kanal değişimi (~240 değişim): taban ısınmadan sonra 630–670 MB'ta düz (−2 MB). Daha önce yazılan "değişim başına ~0.7 MB" bu salınımın tekil örneklerle okunmasıydı. Darlaştırmak için: `-Channels 2` (az sayıda kanal), `-Mpv "hwdec=no;vid=no"` (mpv ayarı).
- **Zaman kaydırma tamponu diske yazar**: canlı kanal izlenirken yayın, seçilen boyuta kadar (varsayılan 2 GB) veri klasöründeki `timeshift` altına geçici olarak yazılır; kanal değişince ve kapanışta silinir. Tercihler'den kapatılabilir.
- **Ebeveyn PIN'i ekranı korur, dosyayı değil**: PIN tuzlu ve özetlenmiş saklanır, art arda 5 yanlış denemeden sonra 30 sn beklenir; ama 4-6 haneli bir kod, kütüphane dosyasına erişen birine karşı koruma değildir.

## Lisans, katkı, güvenlik

- **Lisans:** [Mozilla Public License 2.0](LICENSE). Değiştirdiğiniz dosyalar MPL altında açık kalır; başka kodla birleştirip dağıtabilirsiniz. Üçüncü taraf bileşenler: [THIRD_PARTY.md](THIRD_PARTY.md).
- **Ad ve logo:** "Karadelik" adı ve `assets/brand` altındaki logo lisansa dahil değildir (MPL-2.0 §2.3). Çatallar kendi ad ve logolarıyla dağıtılmalıdır.
- **İçerik:** uygulama yayın, liste veya abonelik içermez ve satmaz. Kullanıcı yalnızca erişim hakkı olduğu kaynakları ekler.
- **Katkı:** [CONTRIBUTING.md](CONTRIBUTING.md). **Güvenlik açığı:** herkese açık issue yerine [SECURITY.md](SECURITY.md).
