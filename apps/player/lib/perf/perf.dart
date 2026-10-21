import 'dart:convert';
import 'dart:io';

/// Appends timing marks to `perf.jsonl` next to the executable, and keeps the
/// latest values in memory for the on-screen HUD.
///
/// Writes are synchronous on purpose: a run that hangs and gets killed must
/// still leave every mark it reached on disk.
class Perf {
  Perf._(this.processStartMs, this._file);

  /// Unix ms when Windows created the process (from the runner), if known.
  final int? processStartMs;
  final File? _file;
  final Map<String, int> latest = {};

  static Perf init(List<String> args) {
    int? start;
    for (final a in args) {
      if (a.startsWith('--kp-process-start-ms=')) {
        start = int.tryParse(a.split('=').last);
      }
    }
    final dir = File(Platform.resolvedExecutable).parent.path;
    return Perf._(start, File('$dir${Platform.pathSeparator}perf.jsonl'));
  }

  int get nowMs => DateTime.now().millisecondsSinceEpoch;

  /// Milliseconds since the process was created.
  int? sinceProcessStart() =>
      processStartMs == null ? null : nowMs - processStartMs!;

  void record(String name, int ms, [Map<String, Object?> extra = const {}]) {
    latest[name] = ms;
    try {
      _file?.writeAsStringSync(
        '${jsonEncode({'t': nowMs, 'name': name, 'ms': ms, ...extra})}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // A read-only install directory must not break the app.
    }
  }

  /// Marks a startup stage with the time since process creation.
  void mark(String stage) => record('mark:$stage', sinceProcessStart() ?? -1);
}
