import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import 'platform.dart';

/// Adds what Flutter does not list by itself to the licenses page: the
/// native player (libmpv, FFmpeg, ANGLE) and the Rust crates of the core.
/// libmpv and FFmpeg are LGPL: they ship as separate DLLs the user can
/// replace, and their source is named here.
void registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    final tr = languageCode == 'tr';
    if (isMobileOs) {
      yield LicenseEntryWithLineBreaks(const ['libmpv (mpv)', 'FFmpeg'], tr ? _mobile : _mobileEn);
    } else {
      yield LicenseEntryWithLineBreaks(const ['libmpv (mpv)'], tr ? _mpv : _mpvEn);
      yield LicenseEntryWithLineBreaks(const ['FFmpeg'], tr ? _ffmpeg : _ffmpegEn);
      yield LicenseEntryWithLineBreaks(const ['ANGLE'], tr ? _angle : _angleEn);
    }
    final raw = await rootBundle.loadString('assets/licenses/rust.json');
    final crates = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final byLicense = <String, List<String>>{};
    for (final c in crates) {
      byLicense.putIfAbsent(c['license'] as String, () => []).add('${c['name']} ${c['version']}');
    }
    for (final MapEntry(key: license, value: names) in byLicense.entries) {
      yield LicenseEntryWithLineBreaks(
        ['Rust: $license'],
        tr
            ? 'Karadelik IPTV Player çekirdeği şu Rust paketlerini kullanır ($license):\n\n${names.join('\n')}\n\n'
                'Lisans metinleri her paketin kaynak deposunda bulunur.'
            : 'The Karadelik IPTV Player core uses these Rust crates ($license):\n\n${names.join('\n')}\n\n'
                "Each crate's license text is in its source repository.",
      );
    }
  });
}

const _mpv = '''
libmpv-2.dll, mpv (https://mpv.io) projesinin LGPL yapılandırmasıdır (-Dgpl=false).
GNU Lesser General Public License, sürüm 2.1 veya sonrası.

Bu kitaplık uygulamaya dinamik olarak bağlıdır; kurulum klasöründeki libmpv-2.dll
dosyasını kendi derlediğiniz uyumlu bir sürümle değiştirebilirsiniz.

Kaynak: https://github.com/mpv-player/mpv (commit e471496c56)
Derleme betikleri: https://github.com/zhongfly/mpv-winbuild
Kaynak arşivleri: https://github.com/enesbsafak/kiptvplayer/releases/tag/native-deps
Lisans metni: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
''';

const _ffmpeg = '''
FFmpeg (https://ffmpeg.org), libmpv-2.dll içinde, --enable-gpl olmadan derlenmiştir.
GNU Lesser General Public License, sürüm 2.1 veya sonrası.

Kaynak: https://git.ffmpeg.org/ffmpeg.git
Lisans metni: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
''';

const _angle = '''
ANGLE (https://chromium.googlesource.com/angle/angle), libEGL.dll ve libGLESv2.dll.
BSD 3-Clause License. Copyright The ANGLE Project Authors.
''';

const _mpvEn = '''
libmpv-2.dll is the LGPL configuration of mpv (https://mpv.io), built with -Dgpl=false.
GNU Lesser General Public License, version 2.1 or later.

The library is linked dynamically: you may replace libmpv-2.dll in the install
folder with a compatible build of your own.

Source: https://github.com/mpv-player/mpv (commit e471496c56)
Build scripts: https://github.com/zhongfly/mpv-winbuild
Source archives: https://github.com/enesbsafak/kiptvplayer/releases/tag/native-deps
License text: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
''';

const _ffmpegEn = '''
FFmpeg (https://ffmpeg.org), inside libmpv-2.dll, built without --enable-gpl.
GNU Lesser General Public License, version 2.1 or later.

Source: https://git.ffmpeg.org/ffmpeg.git
License text: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
''';

const _angleEn = '''
ANGLE (https://chromium.googlesource.com/angle/angle), libEGL.dll and libGLESv2.dll.
BSD 3-Clause License. Copyright The ANGLE Project Authors.
''';

const _mobile = '''
libmpv (https://mpv.io) ve FFmpeg (https://ffmpeg.org), media_kit projesinin LGPL
("default") derlemesi; GPL bileşenleri içermez.
GNU Lesser General Public License, sürüm 2.1 veya sonrası.

Kitaplıklar uygulamaya paylaşılan kitaplık / dinamik framework olarak bağlıdır.

Android: https://github.com/media-kit/libmpv-android-video-build (v1.1.7)
iOS: https://github.com/media-kit/libmpv-darwin-build (v0.7.2)
Lisans metni: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
''';

const _mobileEn = '''
libmpv (https://mpv.io) and FFmpeg (https://ffmpeg.org), media_kit's LGPL
("default") builds, without GPL components.
GNU Lesser General Public License, version 2.1 or later.

The libraries are linked as shared libraries / dynamic frameworks.

Android: https://github.com/media-kit/libmpv-android-video-build (v1.1.7)
iOS: https://github.com/media-kit/libmpv-darwin-build (v0.7.2)
License text: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
''';
