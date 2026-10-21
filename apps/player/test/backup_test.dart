// Backup and restore from Settings, with the native file dialogs stood in.

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/screens/backup.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'fakes.dart';
import 'widgets_test.dart' show app, setLargeWindow;

class _Dialogs extends FileSelectorPlatform with MockPlatformInterfaceMixin {
  String? saveTo;
  String? open;

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async => saveTo == null ? null : FileSaveLocation(saveTo!);

  @override
  Future<XFile?> openFile({List<XTypeGroup>? acceptedTypeGroups, String? initialDirectory, String? confirmButtonText}) async =>
      open == null ? null : XFile(open!);
}

Future<void> _password(WidgetTester tester, List<String> typed) async {
  final fields = find.byType(TextField);
  for (final (i, t) in typed.indexed) {
    await tester.enterText(fields.at(i), t);
  }
  await tester.tap(find.text('Tamam'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a backup needs a long, repeated password; restore needs it back', (tester) async {
    await setLargeWindow(tester);
    final dialogs = _Dialogs()..saveTo = r'C:\yedek\benim';
    FileSelectorPlatform.instance = dialogs;
    final lib = FakeLibrary(sources: [FakeLibrary.source()]);
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, const SingleChildScrollView(child: BackupSettings())));

    await tester.tap(find.text('Yedek al…'));
    await tester.pumpAndSettle();
    await _password(tester, ['kisa', 'kisa']);
    expect(find.text('En az 8 karakter'), findsOneWidget);
    await _password(tester, ['uzun parola 1', 'uzun parola 2']);
    expect(find.text('Parolalar aynı değil'), findsOneWidget);
    await _password(tester, ['uzun parola 1', 'uzun parola 1']);
    expect(lib.backupFiles, {r'C:\yedek\benim.kpbackup': 'uzun parola 1'}, reason: 'extension added');
    expect(find.textContaining('Yedek kaydedildi: 1 kaynak'), findsOneWidget);

    dialogs.open = r'C:\yedek\benim.kpbackup';
    await tester.tap(find.text('Yedekten geri yükle…'));
    await tester.pumpAndSettle();
    await _password(tester, ['yanlış parola']);
    expect(find.text('Parola yanlış ya da dosya bozuk'), findsOneWidget);

    final version = h.state.catalogVersion;
    await tester.tap(find.text('Yedekten geri yükle…'));
    await tester.pumpAndSettle();
    await _password(tester, ['uzun parola 1']);
    expect(find.textContaining('Geri yüklendi: 1 kaynak'), findsOneWidget);
    expect(h.state.catalogVersion, greaterThan(version), reason: 'lists reload');
  });
}
