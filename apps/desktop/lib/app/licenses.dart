import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds what Flutter does not list by itself to the licenses page: the
/// native player (libmpv, FFmpeg, ANGLE) and the Rust crates of the core.
/// libmpv and FFmpeg are LGPL: they ship as separate DLLs the user can
/// replace, and their source is named here.
void registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(['libmpv (mpv)'], _mpv);
    yield const LicenseEntryWithLineBreaks(['FFmpeg'], _ffmpeg);
    yield const LicenseEntryWithLineBreaks(['ANGLE'], _angle);
    final raw = await rootBundle.loadString('assets/licenses/rust.json');
    final crates = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final byLicense = <String, List<String>>{};
    for (final c in crates) {
      byLicense.putIfAbsent(c['license'] as String, () => []).add('${c['name']} ${c['version']}');
    }
    for (final MapEntry(key: license, value: names) in byLicense.entries) {
      yield LicenseEntryWithLineBreaks(
        ['Rust: $license'],
        'Karadelik IPTV Player çekirdeği şu Rust paketlerini kullanır ($license):\n\n${names.join('\n')}\n\n'
        'Lisans metinleri her paketin kaynak deposunda bulunur.',
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
